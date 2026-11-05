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

/*
 * Driver for the ospreySi539xSeq SPI sequencer engines (one per Si539x).
 * Knows nothing about the chip itself: callers build the command lists.
 */
#include <stdio.h>
#include <stdint.h>
#include <xil_io.h>
#include <xparameters.h>
#include "gpio.h"
#include "ospreySi539xSeq.h"
#include "util.h"

#ifdef XPAR_CPU_CORE_CLOCK_FREQ_HZ
#define ENGINE_CLOCK_HZ XPAR_CPU_CORE_CLOCK_FREQ_HZ  /* engines share the CPU's AXI clock */
#else
#define ENGINE_CLOCK_HZ 100000000
#endif

static const uint32_t baseAddress[SI539XSEQ_COUNT] = {
    XPAR_JTRSEQ1_BASEADDR,
    XPAR_JTRSEQ2_BASEADDR,
};

static uint32_t
rd(unsigned ch, unsigned offset)
{
    return Xil_In32(baseAddress[ch] + offset);
}

static void
wr(unsigned ch, unsigned offset, uint32_t value)
{
    Xil_Out32(baseAddress[ch] + offset, value);
}

static int
expired(uint32_t start, uint32_t timeoutUs)
{
    return (uint32_t)(microsecondsSinceBoot() - start) > timeoutUs;
}

uint32_t
si539xSeqClocksPerUs(void)
{
    return ENGINE_CLOCK_HZ / 1000000;
}

int
si539xSeqPresent(unsigned ch)
{
    if (ch >= SI539XSEQ_COUNT) return 0;
    return rd(ch, SI539XSEQ_ID) == SI539XSEQ_ID_VALUE;
}

uint32_t
si539xSeqGetReg(unsigned ch, unsigned offset)
{
    if (ch >= SI539XSEQ_COUNT) return 0;
    return rd(ch, offset);
}

void
si539xSeqSetReg(unsigned ch, unsigned offset, uint32_t value)
{
    if (ch >= SI539XSEQ_COUNT) return;
    wr(ch, offset, value);
}

/*
 * Read-modify-write of CONTROL. Never starts a sequence: use si539xSeqRun().
 */
void
si539xSeqControl(unsigned ch, uint32_t setBits, uint32_t clearBits)
{
    uint32_t v;
    if (ch >= SI539XSEQ_COUNT) return;
    v = rd(ch, SI539XSEQ_CONTROL);
    v = (v | setBits) & ~clearBits;
    wr(ch, SI539XSEQ_CONTROL, v & ~SI539XSEQ_CTL_SEQ_GO);
}

/*
 * Load a command list (an END is appended), start it, and wait for SEQ_DONE.
 * If a poll pass is running, the sequence starts once that pass finishes,
 * so allow for the poll pass length in the timeout.
 * Results of READ entries can then be read back with si539xSeqWord().
 */
int
si539xSeqRun(unsigned ch, const uint32_t *cmds, unsigned n, uint32_t timeoutUs)
{
    uint32_t start = microsecondsSinceBoot();
    unsigned i;

    if (ch >= SI539XSEQ_COUNT) return SI539XSEQ_ERR_CHANNEL;
    if (n >= SI539XSEQ_SEQ_DEPTH) return SI539XSEQ_ERR_LENGTH;

    /* Never rewrite the memory while the engine may be running from it */
    while (rd(ch, SI539XSEQ_STATUS) & SI539XSEQ_STS_SEQ_BUSY) {
        if (expired(start, timeoutUs)) return SI539XSEQ_ERR_BUSY;
    }
    for (i = 0 ; i < n ; i++) {
        wr(ch, SI539XSEQ_SEQ_MEM + 4 * i, cmds[i]);
    }
    wr(ch, SI539XSEQ_SEQ_MEM + 4 * n, SI539XSEQ_END);

    wr(ch, SI539XSEQ_CONTROL, rd(ch, SI539XSEQ_CONTROL) | SI539XSEQ_CTL_SEQ_GO);

    /* Finished means DONE set and BUSY clear */
    for (;;) {
        uint32_t s = rd(ch, SI539XSEQ_STATUS);
        if ((s & (SI539XSEQ_STS_SEQ_BUSY | SI539XSEQ_STS_SEQ_DONE)) == SI539XSEQ_STS_SEQ_DONE)
            return 0;
        if (expired(start, timeoutUs)) return SI539XSEQ_ERR_TIMEOUT;
    }
}

uint32_t
si539xSeqWord(unsigned ch, unsigned index)
{
    if ((ch >= SI539XSEQ_COUNT) || (index >= SI539XSEQ_SEQ_DEPTH)) return 0;
    return rd(ch, SI539XSEQ_SEQ_MEM + 4 * index);
}

/*
 * Replace the poll program (an END is appended). Polling is stopped and the
 * current pass allowed to finish first; it is left disabled afterwards.
 */
int
si539xSeqPollLoad(unsigned ch, const uint32_t *cmds, unsigned n, uint32_t timeoutUs)
{
    uint32_t start = microsecondsSinceBoot();
    unsigned i;

    if (ch >= SI539XSEQ_COUNT) return SI539XSEQ_ERR_CHANNEL;
    if (n >= SI539XSEQ_POLL_DEPTH) return SI539XSEQ_ERR_LENGTH;

    si539xSeqControl(ch, 0, SI539XSEQ_CTL_POLL_EN);
    while (rd(ch, SI539XSEQ_STATUS) & SI539XSEQ_STS_POLL_BUSY) {
        if (expired(start, timeoutUs)) return SI539XSEQ_ERR_TIMEOUT;
    }
    for (i = 0 ; i < n ; i++) {
        wr(ch, SI539XSEQ_POLL_MEM + 4 * i, cmds[i]);
    }
    wr(ch, SI539XSEQ_POLL_MEM + 4 * n, SI539XSEQ_END);
    return 0;
}

void
si539xSeqPollEnable(unsigned ch, int enable)
{
    if (enable) si539xSeqControl(ch, SI539XSEQ_CTL_POLL_EN, 0);
    else        si539xSeqControl(ch, 0, SI539XSEQ_CTL_POLL_EN);
}

uint32_t
si539xSeqPollWord(unsigned ch, unsigned index)
{
    if ((ch >= SI539XSEQ_COUNT) || (index >= SI539XSEQ_POLL_DEPTH)) return 0;
    return rd(ch, SI539XSEQ_POLL_MEM + 4 * index);
}

void
si539xSeqShowStatus(unsigned ch)
{
    uint32_t ctl, sts;
    if (ch >= SI539XSEQ_COUNT) return;
    ctl = rd(ch, SI539XSEQ_CONTROL);
    sts = rd(ch, SI539XSEQ_STATUS);
    printf("jtr%u sequencer at 0x%08x, ID 0x%08x%s\n", ch + 1,
           (unsigned)baseAddress[ch], (unsigned)rd(ch, SI539XSEQ_ID),
           si539xSeqPresent(ch) ? "" : " (UNEXPECTED)");
    printf("  CONTROL 0x%08x: POLL_EN %d, CHIP_RESET %d, CLKBUF_DIS %d, LVLSHIFT_DIS %d\n",
           (unsigned)ctl,
           !!(ctl & SI539XSEQ_CTL_POLL_EN), !!(ctl & SI539XSEQ_CTL_CHIP_RESET),
           !!(ctl & SI539XSEQ_CTL_CLKBUF_DIS), !!(ctl & SI539XSEQ_CTL_LVLSHIFT_DIS));
    printf("  STATUS  0x%08x: SEQ_BUSY %d, SEQ_DONE %d, POLL_BUSY %d, pins LOLb %d LOS_XAXBb %d INTRb %d\n",
           (unsigned)sts,
           !!(sts & SI539XSEQ_STS_SEQ_BUSY), !!(sts & SI539XSEQ_STS_SEQ_DONE),
           !!(sts & SI539XSEQ_STS_POLL_BUSY), !!(sts & SI539XSEQ_STS_PIN_LOL),
           !!(sts & SI539XSEQ_STS_PIN_LOS_XAXB), !!(sts & SI539XSEQ_STS_PIN_INTR));
    printf("  SCLK_DIV %u, CS_GAP %u, SEQ_INDEX %u, POLL_COUNT %u\n",
           (unsigned)rd(ch, SI539XSEQ_SCLK_DIV), (unsigned)rd(ch, SI539XSEQ_CS_GAP),
           (unsigned)rd(ch, SI539XSEQ_SEQ_INDEX), (unsigned)rd(ch, SI539XSEQ_POLL_COUNT));
}
