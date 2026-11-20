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

#include <stdbool.h>
#include <stdio.h>
#include <stdint.h>

#include "gpio.h"
#include "ospreySi539xSeq.h"
#include "ospreyTRGOUT.h"
#include "xparameters.h"
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

static
struct si5394Info {
    // set to 1 if FMC eeprom decoded and sequencer core presents
    // set to 2 if Si5394 also detected
    uint8_t present;
    // true after latest settings written
    bool insync;

    union ident {
        // 5 bytes from device registers: 2-5, 9
        uint8_t u1[8];
        uint32_t u4[2];
    } ident;

    // 4 bytes from device registers: (MSB) 0x11, 0x12, 0x13, 0x53f (LSB)
    uint32_t status;
} si5394Info[SI539XSEQ_COUNT];

static
const uint32_t si539xPollSeq[] = {
    SI539x_PAGE(0x0),
    SI539x_READ(0x11, 0), // read latched for history
    SI539x_READ(0x12, 0),
    SI539x_READ(0x13, 0),
    // a small-ish interval when a momentary fault would be lost
    SI539x_WRITE(0x11, 0), // clear latches
    SI539x_WRITE(0x12, 0),
    SI539x_WRITE(0x13, 0),
    SI539x_PAGE(0x5),
    SI539x_READ(0x53f, 0),
    // wait ~1 second between poll cycles
    SI539x_DELAY(1000u),
};
// ensure delay can be represented
STATIC_ASSERT((XPAR_CPU_CORE_CLOCK_FREQ_HZ & 0x0FFFFFFF) == XPAR_CPU_CORE_CLOCK_FREQ_HZ);

static
const struct si539xSetting si539xSetupSeq[] = {
// see si5394Program.py
// and Design-Report.txt exported from Skyworks CBPro
#include "Design-Report.h"
};
// scratch space to read back default register values after reset
static
uint8_t si539xSetupInitial[NELEM(si539xSetupSeq)];

void ospreyTRGOUTinit()
{
    unsigned ch, any = 0;

    if (!(GPIO_READ(GPIO_IDX_TRGOUT_JTR1_SPI) & JTR_PRESENT))
        return; // FMC2 not present

    printf("%s start\n", __func__);

    for (ch = 0 ; ch < SI539XSEQ_COUNT ; ch++) {
        struct si5394Info* const I = &si5394Info[ch];
        if(si539xSeqPresent(ch))
            I->present = 1; // core is present
        if (!I->present) {
            printf("ERR jtr%u: sequencer ID 0x%08x, expected 0x%08x\n", ch + 1,
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
        struct si5394Info* const I = &si5394Info[ch];
        if (I->present) {
            printf("%s(%u) unreset\n", __func__, ch);
            si539xSeqControl(ch, 0, SI539XSEQ_CTL_CHIP_RESET);
        }
    }
    microsecondSpin(SI539X_READY_US);
    for (ch = 0 ; ch < SI539XSEQ_COUNT ; ch++) {
        struct si5394Info* const I = &si5394Info[ch];
        if (!I->present)
            continue;

        // sequence of ID registers to read once
        static
        const uint32_t IdSeq[] = {
            SI539x_PAGE(0x0),
            SI539x_READ(0x02, 0),
            SI539x_READ(0x03, 0),
            SI539x_READ(0x04, 0),
            SI539x_READ(0x05, 0),
            SI539x_READ(0x09, 0),
        };

        if (si539xLoadSeq(SI539x_MAIN(ch), IdSeq, NELEM(IdSeq))
            || si539xStartStop(SI539x_MAIN(ch), 1))
        {
            I->present = 0;
            continue;
        }
    }
    for (ch = 0 ; ch < SI539XSEQ_COUNT ; ch++) {
        struct si5394Info* const I = &si5394Info[ch];
        if (!I->present)
            continue;
        printf("%s(%u) wait\n", __func__, ch);

        while (si539xIsIdle(SI539x_MAIN(ch))==0) {
            microsecondSpin(100);
        }

        for(size_t i=0; i<5; i++) {
            I->ident.u1[i] = si539xReadSeq(SI539x_MAIN(ch), i+1);
        }
        // assert registers 2 and 3
        if (I->ident.u1[0]!=0x94 || I->ident.u1[1]!=0x53) {
            printf("ERR jtr%u Found Si5394 ID 0x%02x%02x !?!\n", ch, I->ident.u1[1], I->ident.u1[0]);
            continue;
        }
        printf("%s(%u) prepare\n", __func__, ch);

        // read back initial value of registers modified by the setup sequence
        if (si539xCompileSeq(SI539x_MAIN(ch), 0,
                             NULL,
                             si539xSetupSeq, NELEM(si539xSetupSeq),
                             NULL, 0)
            || si539xStartStop(SI539x_MAIN(ch), 1))
        {
            I->present = 0;
            continue;
        }
    }
    for (ch = 0 ; ch < SI539XSEQ_COUNT ; ch++) {
        struct si5394Info* const I = &si5394Info[ch];
        if (!I->present)
            continue;
        printf("%s(%u) wait\n", __func__, ch);

        while (si539xIsIdle(SI539x_MAIN(ch))==0) {
            microsecondSpin(100);
        }

        for(size_t idx=0; idx < NELEM(si539xSetupSeq); idx++) {
            if(si539xSetupSeq[idx].action==si539xActionReg) {
                si539xSetupInitial[idx] = si539xReadSeq(SI539x_MAIN(ch), idx);
            }
        }

        // Setup the poll sequence
        if (si539xLoadSeq(SI539x_POLL(ch), si539xPollSeq, NELEM(si539xPollSeq))
            || si539xStartStop(SI539x_POLL(ch), 1))
        {
            I->present = 0;
            continue;
        }
        I->present = 2;
    }
    printf("%s ", __func__);
    for (ch = 0 ; ch < SI539XSEQ_COUNT ; ch++) {
        struct si5394Info* const I = &si5394Info[ch];
        printf(" %u", I->present);
    }
    printf("\n");
}

// TODO: runtime overrides
static
struct si539xSetting si539xSetupOverrides[] = {};

void ospreyTRGOUTcrank()
{
    static enum {
        Idle,
        Writing,
        Fault,
    } state[SI539XSEQ_COUNT];

    for (unsigned ch = 0 ; ch < SI539XSEQ_COUNT ; ch++) {
        struct si5394Info* const I = &si5394Info[ch];
        if (I->present < 2)
            continue;

        bool polled = false;
        for(unsigned tries=0; tries < 5; tries++) {
            uint32_t before = si539xSeqGetReg(ch, SI539XSEQ_POLL_COUNT);
            uint32_t update = 0;
            for(unsigned i=1; i<=3; i++) { // 0x11, 12, 13
                update |= si539xReadSeq(SI539x_POLL(ch), i);
                update <<= 8;
            }
            update |= si539xReadSeq(SI539x_POLL(ch), 8); // 0x53f

            uint32_t after = si539xSeqGetReg(ch, SI539XSEQ_POLL_COUNT);
            if(before!=after)
                continue;

            // bit 8 of 0x11 is not documented as used, so we use as invalid flag
            update &= ~0x80000000;
            I->status |= update;
            polled = true;
            break;
        }
        if(!polled)
            I->status |= 0x80000000; // poll timeout

        switch(state[ch]) {
        case Idle: // start new sync
            if(!I->insync) {
                printf("%s(%u) start sync\n", __func__, ch);
                // disable output prior to reset
                si539xSeqControl(ch, SI539XSEQ_CTL_CLKBUF_DIS, 0);
                // TODO: full reset?

                if (si539xCompileSeq(SI539x_MAIN(ch), 1,
                                     si539xSetupInitial,
                                     si539xSetupSeq, NELEM(si539xSetupSeq),
                                     si539xSetupOverrides, NELEM(si539xSetupOverrides))
                    || si539xStartStop(SI539x_MAIN(ch), 1))
                {
                    printf("jtr%u operation fault\n", ch);
                    state[ch] = Fault;
                } else {
                    state[ch] = Writing;
                }
                I->insync = true;
            }
            break;
        case Writing: // wait for completion
            switch(si539xIsIdle(SI539x_MAIN(ch))) {
            case 1: // now idle
                state[ch] = Idle;
                si539xSeqControl(ch, 0, SI539XSEQ_CTL_CLKBUF_DIS);
                printf("%s(%u) complete sync\n", __func__, ch);
                break;
            case 0: // busy..
                break;
            default: // error
                printf("ERR jtr%u operation incomplete\n", ch);
                state[ch] = Fault;
                break;
            }
            break;
        case Fault:
            break; // stick
        }
    }
}

uint32_t osreyTRGOUTRead(uint32_t addr)
{
    struct si5394Info* const I = &si5394Info[addr&1];
    uint32_t idx = addr>>1;
    switch(addr) {
    case 0 ... 3: return I->ident.u4[idx];
    case 4 ... 5: { // clear on read...
        uint32_t ret = I->status;
        I->status = 0;
        return ret;
    }
    case TRGOUT_SIZE ... 256: // compile error if TRGOUT_SIZE too small
    default:
        return 0xdeadbeef;
    }
}

void osreyTRGOUTWrite(uint32_t addr) {}

static
void manualmode(unsigned int ch, bool write, const struct si539xSetting *regs, size_t nregs)
{
    struct si5394Info* const I = &si5394Info[ch];
    if(I->present < 2) {
        printf("...Nope\n");
        return;
    }
    while (si539xIsIdle(SI539x_MAIN(ch))==0) {
        microsecondSpin(100);
    }
    if (si539xCompileSeq(SI539x_MAIN(ch), write,
                         NULL,
                         regs, nregs,
                         NULL, 0)
        || si539xStartStop(SI539x_MAIN(ch), 1))
    {
        printf("Error\n");
        return;
    }
    while (si539xIsIdle(SI539x_MAIN(ch))==0) {
        microsecondSpin(100);
    }

    if(write)
        return;

    for(size_t i=0; i<nregs; i++) {
        if(regs[i].action==si539xActionReg)
            printf("  0x%04X 0x%02X\n", regs[i].addr, si539xReadSeq(SI539x_MAIN(ch), i));
    }
}

void ospreyTRGOUTdump(unsigned int ch)
{
    manualmode(ch, false, si539xSetupSeq, NELEM(si539xSetupSeq));
}

void si539xWrite(unsigned int ch, uint16_t addr, uint8_t val)
{
    struct si539xSetting reg[2] = {
        SI539x_SEQ_PAGE(addr>>8),
        SI539x_SEQ_REG(addr, 0xff, val),
    };
    manualmode(ch, true, reg, NELEM(reg));
}

void si539xRead(unsigned int ch, uint16_t addr)
{
    struct si539xSetting reg[2] = {
        SI539x_SEQ_PAGE(addr>>8),
        SI539x_SEQ_REG(addr, 0, 0),
    };
    manualmode(ch, false, reg, NELEM(reg));
}
