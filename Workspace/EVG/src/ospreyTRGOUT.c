/*
 * MIT License
 *
 * Copyright (c) 2026 Osprey DCS
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#include <stdio.h>
#include <stdint.h>

#include "gpio.h"
#include "ospreySi539xSeq.h"
#include "ospreyTRGOUT.h"
#include "util.h"

/*
 * The Si5394 jitter cleaners on the Trigger Output FMC are driven by the two
 * ospreySi539xSeq engines (reset, output enables and SPI). The old GPIO
 * register is only used for its card-present bit.
 */
#define JTR_PRESENT 0x80000000

/* Si539x needs up to 15 ms after RSTb is released before SPI is usable */
#define SI539X_READY_US  20000
/* Allow for a poll pass in progress before a sequence can start */
#define SEQ_TIMEOUT_US   100000

static int present[SI539XSEQ_COUNT];

static int
checkChannel(unsigned ch)
{
    if ((ch < SI539XSEQ_COUNT) && present[ch]) return 1;
    printf("jtr%u: not available (card absent or no sequencer)\n", ch + 1);
    return 0;
}

static void
reportError(unsigned ch, const char *what, int err)
{
    printf("jtr%u: %s failed (%d)\n", ch + 1, what, err);
}

/*
 * Single register access in the current page, through the sequencer.
 * Callers select the page by writing register 0x01, as before.
 */
void si539xWrite(unsigned ch, uint8_t addr, uint8_t val)
{
    uint32_t cmd = si539xSeqWrite(addr, val);
    int err;
    if (!checkChannel(ch)) return;
    err = si539xSeqRun(ch, &cmd, 1, SEQ_TIMEOUT_US);
    if (err) reportError(ch, "write", err);
}

uint8_t si539xRead(unsigned ch, uint8_t addr)
{
    uint32_t cmd = si539xSeqRead(addr, 0);
    int err;
    if (!checkChannel(ch)) return 0;
    err = si539xSeqRun(ch, &cmd, 1, SEQ_TIMEOUT_US);
    if (err) {
        reportError(ch, "read", err);
        return 0;
    }
    return SI539XSEQ_WORD_RESULT(si539xSeqWord(ch, 0));
}

/*
 * Read and show the identification registers 0x0002-0x000A in one sequence.
 */
static void
showID(unsigned ch)
{
    uint32_t cmds[10];
    unsigned n = 0, i;
    int err;

    cmds[n++] = si539xSeqPage(0x00);
    for (i = 0x02 ; i <= 0x0A ; i++) cmds[n++] = si539xSeqRead(i, 0);
    err = si539xSeqRun(ch, cmds, n, SEQ_TIMEOUT_US);
    if (err) {
        reportError(ch, "ID read", err);
        return;
    }
    printf("jtr%u: Si%02X%02X, grade register 0x%02X, revision register 0x%02X\n",
           ch + 1,
           (unsigned)SI539XSEQ_WORD_RESULT(si539xSeqWord(ch, 2)),
           (unsigned)SI539XSEQ_WORD_RESULT(si539xSeqWord(ch, 1)),
           (unsigned)SI539XSEQ_WORD_RESULT(si539xSeqWord(ch, 3)),
           (unsigned)SI539XSEQ_WORD_RESULT(si539xSeqWord(ch, 4)));
    for (i = 1 ; i < n ; i++) {
        uint32_t w = si539xSeqWord(ch, i);
        printf("  0x%04X 0x%02X\n", (unsigned)SI539XSEQ_WORD_REG(w),
                                    (unsigned)SI539XSEQ_WORD_RESULT(w));
    }
}

void ospreyTRGOUTinit()
{
    unsigned ch, any = 0;

    if (!(GPIO_READ(GPIO_IDX_TRGOUT_JTR1_SPI) & JTR_PRESENT))
        return; // FMC2 not present

    for (ch = 0 ; ch < SI539XSEQ_COUNT ; ch++) {
        present[ch] = si539xSeqPresent(ch);
        if (!present[ch]) {
            printf("jtr%u: sequencer ID 0x%08x, expected 0x%08x\n", ch + 1,
                   (unsigned)si539xSeqGetReg(ch, SI539XSEQ_ID),
                   (unsigned)SI539XSEQ_ID_VALUE);
            continue;
        }
        // Enable the level shifters with the chip still in reset and its
        // clock outputs disabled.
        si539xSeqControl(ch, SI539XSEQ_CTL_CHIP_RESET | SI539XSEQ_CTL_CLKBUF_DIS,
                             SI539XSEQ_CTL_LVLSHIFT_DIS);
        any = 1;
    }
    if (!any) return;
    microsecondSpin(10);
    for (ch = 0 ; ch < SI539XSEQ_COUNT ; ch++) {
        if (present[ch]) si539xSeqControl(ch, 0, SI539XSEQ_CTL_CHIP_RESET);
    }
    microsecondSpin(SI539X_READY_US);
    for (ch = 0 ; ch < SI539XSEQ_COUNT ; ch++) {
        if (present[ch]) showID(ch);
    }
}

/*
 * Clock buffer outputs on the card (off after start-up).
 */
void ospreyTRGOUTclockOutputs(unsigned ch, int enable)
{
    if (!checkChannel(ch)) return;
    if (enable) si539xSeqControl(ch, 0, SI539XSEQ_CTL_CLKBUF_DIS);
    else        si539xSeqControl(ch, SI539XSEQ_CTL_CLKBUF_DIS, 0);
}

/*
 * Status poll: live and sticky status, active input, holdover/fast lock.
 */
static const uint16_t pollRegs[] = {
    0x000C, 0x000D, 0x000E, 0x000F, 0x0011, 0x0012, 0x0013, 0x0014,
    0x0507, 0x053F,
};
#define POLL_INTERVAL_US 1000

void ospreyTRGOUTpoll(unsigned ch, int enable)
{
    uint32_t cmds[24];
    unsigned n = 0, i;
    int page = -1, err;

    if (!checkChannel(ch)) return;
    if (!enable) {
        si539xSeqPollEnable(ch, 0);
        return;
    }
    for (i = 0 ; i < sizeof pollRegs / sizeof pollRegs[0] ; i++) {
        if ((pollRegs[i] >> 8) != page) {
            page = pollRegs[i] >> 8;
            cmds[n++] = si539xSeqPage(page);
        }
        cmds[n++] = si539xSeqRead(pollRegs[i], 0);
    }
    cmds[n++] = si539xSeqDelay(POLL_INTERVAL_US * si539xSeqClocksPerUs());
    err = si539xSeqPollLoad(ch, cmds, n, SEQ_TIMEOUT_US);
    if (err) {
        reportError(ch, "poll load", err);
        return;
    }
    si539xSeqPollEnable(ch, 1);
}

void ospreyTRGOUTshowPoll(unsigned ch)
{
    uint32_t before, after, words[SI539XSEQ_POLL_DEPTH];
    unsigned i, tries = 0;

    if (!checkChannel(ch)) return;
    // Take a consistent copy: POLL_COUNT unchanged across the reads
    do {
        before = si539xSeqGetReg(ch, SI539XSEQ_POLL_COUNT);
        for (i = 0 ; i < SI539XSEQ_POLL_DEPTH ; i++) {
            words[i] = si539xSeqPollWord(ch, i);
            if ((words[i] >> 28) == SI539XSEQ_OP_END) break;
        }
        after = si539xSeqGetReg(ch, SI539XSEQ_POLL_COUNT);
    } while ((before != after) && (++tries < 5));

    printf("jtr%u poll: %s, %u passes\n", ch + 1,
           (si539xSeqGetReg(ch, SI539XSEQ_CONTROL) & SI539XSEQ_CTL_POLL_EN) ? "on" : "off",
           (unsigned)after);
    if (after == 0) return;
    for (i = 0 ; i < SI539XSEQ_POLL_DEPTH ; i++) {
        uint32_t w = words[i];
        if ((w >> 28) == SI539XSEQ_OP_END) break;
        if ((w >> 28) == SI539XSEQ_OP_READ) {
            printf("  0x%02X%02X 0x%02X\n", (unsigned)SI539XSEQ_WORD_PAGE(w),
                   (unsigned)SI539XSEQ_WORD_REG(w),
                   (unsigned)SI539XSEQ_WORD_RESULT(w));
        }
    }
}

void ospreyTRGOUTshowStatus(unsigned ch)
{
    if (ch >= SI539XSEQ_COUNT) return;
    si539xSeqShowStatus(ch);
}

uint32_t osreyTRGOUTRead(uint32_t addr) { return 0; }
void osreyTRGOUTWrite(uint32_t addr) {}
