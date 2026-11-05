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
#include "si5394Registers.h"
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

/*
 * Full configuration from the ClockBuilder Pro register list in
 * si5394Registers.h (Pedro Rodriguez): preamble, the post-preamble wait,
 * then the register map (which ends with the postamble), as one sequence.
 * Then a verify pass reads the registers back.
 */
#define N_ELEMENTS(a) (sizeof (a) / sizeof (a)[0])
#define CONFIG_TIMEOUT_US 2000000

static uint32_t cmdBuf[SI539XSEQ_SEQ_DEPTH];   // too big for the stack

static int
inList(uint16_t addr, const si5394Reg_t *list, unsigned count)
{
    unsigned i;
    for (i = 0 ; i < count ; i++) if (list[i].addr == addr) return 1;
    return 0;
}

/*
 * Registers whose read-back need not match what was written: the pre- and
 * postamble mode/trigger registers, and the divider update strobes.
 */
static const uint16_t updateStrobes[] = { 0x0230, 0x023F, 0x030C, 0x0338, 0x0520 };

static int
skipVerify(uint16_t addr)
{
    unsigned i;
    if (inList(addr, si5394PreConfig, N_ELEMENTS(si5394PreConfig))) return 1;
    if (inList(addr, si5394PostConfig, N_ELEMENTS(si5394PostConfig))) return 1;
    for (i = 0 ; i < N_ELEMENTS(updateStrobes) ; i++) {
        if (updateStrobes[i] == addr) return 1;
    }
    return 0;
}

/*
 * Append WRITE (or, for verify, READ) entries for a register list, with a
 * page write wherever the page changes. Returns the new length, or
 * SI539XSEQ_SEQ_DEPTH if the list would not fit.
 */
static unsigned
appendRegs(unsigned n, const si5394Reg_t *list, unsigned count, int *page, int verify)
{
    unsigned i;
    for (i = 0 ; i < count ; i++) {
        uint16_t addr = list[i].addr;
        if (verify && skipVerify(addr)) continue;
        if (n + 2 >= SI539XSEQ_SEQ_DEPTH) return SI539XSEQ_SEQ_DEPTH;
        if ((addr >> 8) != *page) {
            *page = addr >> 8;
            cmdBuf[n++] = si539xSeqPage(*page);
        }
        cmdBuf[n++] = verify ? si539xSeqRead(addr, list[i].val)
                             : si539xSeqWrite(addr, list[i].val);
    }
    return n;
}

int ospreyTRGOUTconfigure(unsigned ch)
{
    unsigned n, i, checked = 0, mismatches = 0;
    int page = -1, err;
    uint8_t grade;
    uint32_t waitUs, start, elapsed;

    if (!checkChannel(ch)) return -1;

    // Grades E and P need 625 ms after the preamble, the others 300 ms
    si539xWrite(ch, 0x01, 0x00);
    grade = si539xRead(ch, 0x04);
    waitUs = ((grade == 4) || (grade == 15)) ? 625000 : 300000;

    n = appendRegs(0, si5394PreConfig, N_ELEMENTS(si5394PreConfig), &page, 0);
    cmdBuf[n++] = si539xSeqDelay(waitUs * si539xSeqClocksPerUs());
    n = appendRegs(n, si5394CLKConfig, N_ELEMENTS(si5394CLKConfig), &page, 0);
    if (n >= SI539XSEQ_SEQ_DEPTH) {
        printf("jtr%u: configuration does not fit the sequence memory\n", ch + 1);
        return -1;
    }
    start = microsecondsSinceBoot();
    err = si539xSeqRun(ch, cmdBuf, n, CONFIG_TIMEOUT_US);
    elapsed = microsecondsSinceBoot() - start;
    if (err) {
        reportError(ch, "configuration", err);
        return err;
    }
    printf("jtr%u: configured (grade %u, %u ms wait), %u commands in %u ms\n",
           ch + 1, grade, (unsigned)(waitUs / 1000), n, (unsigned)(elapsed / 1000));

    page = -1;
    n = appendRegs(0, si5394CLKConfig, N_ELEMENTS(si5394CLKConfig), &page, 1);
    err = si539xSeqRun(ch, cmdBuf, n, SEQ_TIMEOUT_US);
    if (err) {
        reportError(ch, "verify", err);
        return err;
    }
    for (i = 0 ; i < n ; i++) {
        uint32_t w = si539xSeqWord(ch, i);
        if ((w >> 28) != SI539XSEQ_OP_READ) continue;
        checked++;
        if (SI539XSEQ_WORD_RESULT(w) != SI539XSEQ_WORD_EXPECTED(w)) {
            if (++mismatches <= 10) {
                printf("  0x%02X%02X read 0x%02X, wrote 0x%02X\n",
                       (unsigned)SI539XSEQ_WORD_PAGE(w), (unsigned)SI539XSEQ_WORD_REG(w),
                       (unsigned)SI539XSEQ_WORD_RESULT(w),
                       (unsigned)SI539XSEQ_WORD_EXPECTED(w));
            }
        }
    }
    printf("jtr%u: verified %u registers, %u mismatch%s\n", ch + 1, checked,
           mismatches, (mismatches == 1) ? "" : "es");
    if (mismatches == 0) printf("jtr%u: clock buffer outputs are still off: jtr%u oe on\n",
                                ch + 1, ch + 1);
    return mismatches ? -1 : 0;
}

/*
 * Clear the sticky status flags (0x0011-0x0014).
 */
void ospreyTRGOUTclearSticky(unsigned ch)
{
    uint32_t cmds[5];
    unsigned n = 0, i;
    int err;

    if (!checkChannel(ch)) return;
    cmds[n++] = si539xSeqPage(0x00);
    for (i = 0x11 ; i <= 0x14 ; i++) cmds[n++] = si539xSeqWrite(i, 0x00);
    err = si539xSeqRun(ch, cmds, n, SEQ_TIMEOUT_US);
    if (err) reportError(ch, "clear", err);
}

uint32_t osreyTRGOUTRead(uint32_t addr) { return 0; }
void osreyTRGOUTWrite(uint32_t addr) {}
