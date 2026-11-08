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

STATIC_ASSERT(sizeof(struct si539xSetting)==4);

static const uint32_t baseAddress[SI539XSEQ_COUNT] = {
    XPAR_JTRSEQ1_BASEADDR,
    XPAR_JTRSEQ2_BASEADDR,
};

static uint32_t
rd(unsigned ch, unsigned offset)
{
    uint32_t ret = Xil_In32(baseAddress[ch] + offset);
    //printf("%s(%u) 0x%08x -> 0x%08x\n", __func__, ch, offset, ret);
    return ret;
}

static void
wr(unsigned ch, unsigned offset, uint32_t value)
{
    //printf("%s(%u) 0x%08x <- 0x%08x\n", __func__, ch, offset, value);
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

static
int si539xDest(unsigned dest, unsigned* ch, size_t* base, size_t* depth)
{
    *ch = dest&1;
    switch(dest) {
    case 0x10:
    case 0x11:
        *base = SI539XSEQ_SEQ_MEM;
        *depth= SI539XSEQ_SEQ_DEPTH;
        break;
    case 0x20:
    case 0x21:
        *base = SI539XSEQ_POLL_MEM;
        *depth= SI539XSEQ_POLL_COUNT;
        break;
    default: return SI539XSEQ_ERR_CHANNEL;
    }
    return 0;
}

int si539xLoadSeq(unsigned dest, const uint32_t* cmds, size_t ncmds)
{
    unsigned ch;
    size_t base, depth;
    int err = si539xDest(dest, &ch, &base, &depth);
    if(err)
        return err;

    if(ncmds >= depth-1) // require space for explicit END
        return SI539XSEQ_ERR_LENGTH;

    if(rd(ch, SI539XSEQ_STATUS) & SI539XSEQ_STS_SEQ_BUSY)
        return SI539XSEQ_ERR_BUSY;

    for (size_t i = 0 ; i < ncmds ; i++) {
        wr(ch, base + 4 * i, cmds[i]);
    }
    wr(ch, base + 4 * ncmds, SI539XSEQ_END);
    return 0;
}

int si539xCompileSeq(unsigned dest, bool write,
                     const uint8_t *initials,
                     const struct si539xSetting* settings, size_t nsettings,
                     const struct si539xSetting* overrides, size_t noverrides)
{
    unsigned ch;
    size_t base, depth;
    int err = si539xDest(dest, &ch, &base, &depth);
    if(err || !settings)
        return err;

    if(nsettings >= depth-1) // require space for explicit END
        return SI539XSEQ_ERR_LENGTH;

    int current_page = -1;
    for (size_t i = 0 ; i < nsettings && i < depth ; i++) {
        switch(settings[i].action) {
        case si539xActionPage: // set PAGE
            wr(ch, base + 4 * i, SI539x_PAGE(settings[i].addr));
            current_page = settings[i].addr;
            break;

        case si539xActionDelay: // set DELAY (skip when reading)
            wr(ch, base + 4 * i, SI539x_DELAY(write ? settings[i].addr : 0));
            break;

        case si539xActionReg:
            if(settings[i].addr>>8 != current_page) {
                printf("%s(%p) ERR: missing PAGE %uz 0x%03x\n", __func__, settings, i, settings[i].addr);
                return SI539XSEQ_ERR_INVALID;
            }

            if(!write) {
                wr(ch, base + 4 * i, SI539x_READ(settings[i].addr, 0));

            } else { // writing
                // begin with initial value
                uint8_t cur = initials ? initials[i] : 0;
                // apply primary setting
                cur &= ~settings[i].mask;
                cur |= settings[i].value & settings[i].mask;

                // apply any active overrides
                for(size_t next_over = 0; next_over < noverrides; next_over++) {
                    const struct si539xSetting *O = &overrides[next_over];

                    if(O->action == si539xActionReg && O->addr == settings[i].addr) {
                        cur &= ~overrides[next_over].mask;
                        cur |= overrides[next_over].value & overrides[next_over].mask;
                    }
                }

                wr(ch, base + 4 * i, SI539x_WRITE(settings[i].addr, cur));
            }
            break;

        default:
            printf("%s(%p) ERR: bad inst %uz\n", __func__, settings, i);
            return SI539XSEQ_ERR_INVALID;
        }
    }
    wr(ch, base + 4 * nsettings, SI539XSEQ_END);
    return 0;
}

uint8_t si539xReadSeq(unsigned dest, size_t idx)
{
    return SI539XSEQ_WORD_RESULT(si539xReadSeqInstr(dest, idx));
}

uint32_t si539xReadSeqInstr(unsigned int dest, size_t idx)
{
    unsigned ch;
    size_t base, depth;
    int err = si539xDest(dest, &ch, &base, &depth);
    if(err || idx >= depth)
        return 0xff;

    return rd(ch, base + 4 * idx);
}

int si539xStartStop(unsigned dest, unsigned start)
{
    unsigned ch = dest&1;
    switch(dest) {
    case 0x10:
    case 0x11:
        if(start)
            wr(ch, SI539XSEQ_CONTROL, rd(ch, SI539XSEQ_CONTROL) | SI539XSEQ_CTL_SEQ_GO);
        return 0;
    case 0x20:
    case 0x21:
        if (start) si539xSeqControl(ch, SI539XSEQ_CTL_POLL_EN, 0);
        else       si539xSeqControl(ch, 0, SI539XSEQ_CTL_POLL_EN);
        return 0;
    default: return SI539XSEQ_ERR_CHANNEL;
    }
}

int si539xIsIdle(unsigned dest)
{
    unsigned ch = dest&1;
    switch(dest) {
    case 0x10:
    case 0x11:
        return (rd(ch, SI539XSEQ_STATUS) & SI539XSEQ_STS_SEQ_BUSY)==0;
        break;
    case 0x20:
    case 0x21:
        return (rd(ch, SI539XSEQ_STATUS) & SI539XSEQ_STS_POLL_BUSY)==0;
    default: return SI539XSEQ_ERR_CHANNEL;
    }
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
