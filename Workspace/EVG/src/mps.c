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
 * Machine protection support
 */

#include <stdio.h>
#include <xparameters.h>
#include "gpio.h"
#include "mps.h"
#include "util.h"

#define CSR_MPS_OUTPUT_SEL_MASK         0x0F
#define CSR_MPS_REG_SEL_MASK            0x0F0
#define CSR_MPS_REG_SEL_SHIFT           4
#define CSR_MPS_R_INVERT_MASK           0xFF00
#define CSR_MPS_R_INVERT_SHIFT          8
#define CSR_MPS_R_FORCE_TRIP_MASK       0xFF0000
#define CSR_MPS_R_FORCE_TRIP_SHIFT      16
#define CSR_MPS_W_INVERT                0x1000000
#define CSR_MPS_W_FORCE_TRIP            0x2000000
# define CSR_REG_DISCRETE_BITMAP        0x000
# define CSR_REG_DISCRETE_GOOD_STATE    0x010
# define CSR_REG_FIRST_FAULT_DISCRETE   0x020
# define CSR_REG_FIRST_FAULT_SECONDS    0x030
# define CSR_REG_FIRST_FAULT_TICKS      0x040
# define CSR_REG_STATUS                 0x050

#define STATUS_REG_TRIPPED  0x1
#define STATUS_REG_FAULTED  0x2

#define CSR_WRITE(x)  GPIO_WRITE(GPIO_IDX_MPS_LOCAL_CSR, (x))
#define CSR_READ()    GPIO_READ(GPIO_IDX_MPS_LOCAL_CSR)
#define DATA_WRITE(x) GPIO_WRITE(GPIO_IDX_MPS_LOCAL_DATA, (x))
#define DATA_READ()   GPIO_READ(GPIO_IDX_MPS_LOCAL_DATA)

static uint32_t
getReg(int regSel, int outputIndex)
{
    uint32_t sel = (regSel & CSR_MPS_REG_SEL_MASK) |
                                        (outputIndex & CSR_MPS_OUTPUT_SEL_MASK);
    CSR_WRITE(sel);
    return DATA_READ();
}

static void
setReg(int regSel, int outputIndex, uint32_t value)
{
    uint32_t sel = (regSel & CSR_MPS_REG_SEL_MASK) |
                                        (outputIndex & CSR_MPS_OUTPUT_SEL_MASK);
    CSR_WRITE(sel);
    DATA_WRITE(value);
}

void
mpsDumpReg(void)
{
    int o;
    uint32_t v;
    for (o = 0 ; o < CFG_MPS_OUTPUT_COUNT ; o++) {
        int r;
        v = getReg(CSR_REG_STATUS, o);
        static const char * const names[] = {
            "Check Digital",
            "GOOD state",
            "First Fault Digital",
            "First Fault Seconds",
            "First Fault Ticks",
            "Status" };
        printf("Output %d:%sripped%s\n", o + 1,
                            (v & STATUS_REG_TRIPPED) ? "T" : " Not T",
                            (v & STATUS_REG_FAULTED) ? " (Fault Present)" : "");
        for (r = 0 ; r < sizeof names / sizeof names[0] ; r++) {
            v = getReg((r << CSR_MPS_REG_SEL_SHIFT), o);
            printf("%24s: %04X:%04X\n", names[r], (v >> 16), v & 0xFFFF);
        }
    }
    v = GPIO_READ(GPIO_IDX_MPS_MERGE_CSR);
    printf("Tripped:%02x  Required:%02X\n", v >> 16, v & 0xFFFF);
}

static void
mpsSetDiscreteBitmap(int outputIndex, uint32_t map)
{
    setReg(CSR_REG_DISCRETE_BITMAP, outputIndex, map);
}

static void
mpsSetDiscreteGoodState(int outputIndex, uint32_t goodState)
{
    setReg(CSR_REG_DISCRETE_GOOD_STATE, outputIndex, goodState);
}

static void
mpsSetInvertedInputs(uint32_t map)
{
    map &= (1 << CFG_MPS_INPUT_COUNT) - 1;
    CSR_WRITE(CSR_MPS_W_INVERT | map);
}

static void
mpsSetForceTrip(uint32_t mpsOutputs)
{
    mpsOutputs &= (1 << CFG_MPS_OUTPUT_COUNT) - 1;
    CSR_WRITE(CSR_MPS_W_FORCE_TRIP | mpsOutputs);
}

static void
mpsSetRequiredLinks(uint32_t bitmap)
{
    /* For now the first link is never 'required' since it's the EVR */
printf("mpsSetRequiredLinks %x", bitmap);
    bitmap &= (1 << CFG_MGT_COUNT) - 1 - 1;
printf("  %x\n", bitmap);
    GPIO_WRITE(GPIO_IDX_MPS_MERGE_CSR, 0x10000 | bitmap);
}

static uint32_t
mpsGetDiscreteBitmap(int outputIndex)
{
    return getReg(CSR_REG_DISCRETE_BITMAP, outputIndex);
}

static uint32_t
mpsGetDiscreteGoodState(int outputIndex)
{
    return getReg(CSR_REG_DISCRETE_GOOD_STATE, outputIndex);
}

static uint32_t
mpsGetInvertedInputs(void)
{
    return (CSR_READ() & CSR_MPS_R_INVERT_MASK) >> CSR_MPS_R_INVERT_SHIFT;
}

static uint32_t
mpsGetForceTrip(void)
{
    return (CSR_READ()&CSR_MPS_R_FORCE_TRIP_MASK) >> CSR_MPS_R_FORCE_TRIP_SHIFT;
}

static uint32_t
mpsGetRequiredLinks(void)
{
    return GPIO_READ(GPIO_IDX_MPS_MERGE_CSR) & ((1 << CFG_MGT_COUNT) - 1);
}

static uint32_t
mpsGetTripped(void)
{
    return (GPIO_READ(GPIO_IDX_MPS_MERGE_CSR) >> 16) &
                                                ((1<<CFG_MPS_OUTPUT_COUNT) - 1);
}

static uint32_t
mpsGetFirstFaultDiscrete(int outputIndex)
{
    return getReg(CSR_REG_FIRST_FAULT_DISCRETE, outputIndex);
}

static uint32_t
mpsGetFirstFaultSeconds(int outputIndex)
{
    return getReg(CSR_REG_FIRST_FAULT_SECONDS, outputIndex);
}

static uint32_t
mpsGetFirstFaultTicks(int outputIndex)
{
    return getReg(CSR_REG_FIRST_FAULT_TICKS, outputIndex);
}

static uint32_t
mpsGetStatus(int outputIndex)
{
    return getReg(CSR_REG_STATUS, outputIndex);
}

/*
 * FEED I/O support
 */
#define REG_INVERT_INPUTS       0
#define REG_FORCE_TRIP          1
#define REG_REQUIRED_LINKS      2
#define REG_MERGED_TRIPPED      3
#define REG_STATUS_BASE         100
#define REG_IMPORTANT_BASE      200
#define REG_GOOD_STATE_BASE     300
#define REG_FIRST_FAULT_BASE    400
#define REG_FAULT_SECONDS_BASE  500
#define REG_FAULT_TICKS_BASE    600
#define RANGE(base, count) (base) ... ((base)+(count)-1)

void
mpsWrite(int offset, uint32_t value)
{
    switch(offset) {
    case REG_INVERT_INPUTS:
        mpsSetInvertedInputs(value);
        break;

    case REG_FORCE_TRIP:
        mpsSetForceTrip(value);
        break;

    case REG_REQUIRED_LINKS:
        mpsSetRequiredLinks(value);
        break;

    case RANGE(REG_IMPORTANT_BASE, CFG_MPS_OUTPUT_COUNT):
        mpsSetDiscreteBitmap(offset - REG_IMPORTANT_BASE, value);
        break;

    case RANGE(REG_GOOD_STATE_BASE, CFG_MPS_OUTPUT_COUNT):
        mpsSetDiscreteGoodState(offset - REG_GOOD_STATE_BASE, value);
        break;
    }
}

uint32_t
mpsRead(int offset)
{
    switch(offset) {
    case REG_INVERT_INPUTS:
        return mpsGetInvertedInputs();
        break;

    case REG_FORCE_TRIP:
        return mpsGetForceTrip();
        break;

    case REG_REQUIRED_LINKS:
        return mpsGetRequiredLinks();
        break;

    case REG_MERGED_TRIPPED:
        return mpsGetTripped();
        break;

    case RANGE(REG_STATUS_BASE, CFG_MPS_OUTPUT_COUNT):
        return mpsGetStatus(offset - REG_STATUS_BASE);

    case RANGE(REG_IMPORTANT_BASE, CFG_MPS_OUTPUT_COUNT):
        return mpsGetDiscreteBitmap(offset - REG_IMPORTANT_BASE);

    case RANGE(REG_GOOD_STATE_BASE, CFG_MPS_OUTPUT_COUNT):
        return mpsGetDiscreteGoodState(offset - REG_GOOD_STATE_BASE);

    case RANGE(REG_FIRST_FAULT_BASE, CFG_MPS_OUTPUT_COUNT):
        return mpsGetFirstFaultDiscrete(offset - REG_FIRST_FAULT_BASE);

    case RANGE(REG_FAULT_SECONDS_BASE, CFG_MPS_OUTPUT_COUNT):
        return mpsGetFirstFaultSeconds(offset - REG_FAULT_SECONDS_BASE);

    case RANGE(REG_FAULT_TICKS_BASE, CFG_MPS_OUTPUT_COUNT):
        return mpsGetFirstFaultTicks(offset - REG_FAULT_TICKS_BASE);

    default:
        return (~(uint32_t)0);
    }
}
