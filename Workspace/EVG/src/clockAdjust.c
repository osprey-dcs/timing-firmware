/*
 * MIT License
 *
 * Copyright (c) 2025 Osprey DCS
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
#include "clockAdjust.h"
#include "gpio.h"
#include "util.h"

#define DAC_VALUE_CLOSE_LOOP -32768

#define CSR_W_ENABLE            0x80000000
#define CSR_W_DISABLE           0x40000000
#define CSR_W_SET_DAC           0x20000000
#define CSR_W_IS_OFFSET_BINARY  0x10000000
#define CSR_W_IS_TWOS_COMPLMNT  0x8000000
#define CSR_W_VCXO20            0x10000
#define CSR_W_DAC_MASK          0xFFFF
#define CSR_R_LOCKED            0x80000000
#define CSR_R_DAC_UPDATE_TOGGLE 0x40000000
#define CSR_R_PLL_ENABLED       0x20000000
#define CSR_R_JITTER_IS_HIGH    0x10000000
#define CSR_R_HW_PPS_VALID      0x8000000
#define CSR_R_HW_PPS_TOGGLE     0x4000000
#define CSR_R_IS_OFFSET_BINARY  0x2000000
#define CSR_R_DAC_BUSY          0x1000000
#define CSR_R_PHASE_ERROR_MASK  0xFFFFFF
#define CSR_R_PHASE_ERROR_SIGN  0x800000

#define AUX_JITTER_MASK     0xFFFF0000
#define AUX_JITTER_SHIFT    16
#define AUX_DAC_MASK        0xFFFF
#define AUX_DAC_SIGN        0x8000

#define HW_PPS_VALID            0x80000000
#define HW_PPS_TERTIARY_VALID   0x40000000
#define HW_PPS_SECONDARY_VALID  0x20000000
#define HW_PPS_PRIMARY_VALID    0x10000000
#define HW_PPS_TOGGLE           0x8000000
#define HW_PPS_STATUS_MASK      0xF8000000

/*
 * Fetch register from non-system clock domain
 */
static uint32_t
stableRegister(int idx)
{
    uint32_t oreg, reg;
    int passesLeft = 10;
    oreg = GPIO_READ(idx);
    for (;;) {
        reg = GPIO_READ(idx);
        if ((reg == oreg) || (--passesLeft == 0)) {
            return reg;
        }
        oreg = reg;
    }
}

uint32_t
clockAdjustFetchSysmon(int index)
{
    switch (index) {
    case 0: return stableRegister(GPIO_IDX_MARBLE_VCXO_PLL_CSR);
    case 1: return stableRegister(GPIO_IDX_MARBLE_VCXO_PLL_AUX);
    case 2: return stableRegister(GPIO_IDX_MARBLE_VCXO_HW_PPS);
    }
    return 0;
}

static int
phaseError(uint32_t csr)
{
    int phaseError;
    phaseError = csr & CSR_R_PHASE_ERROR_MASK;
    if (phaseError & CSR_R_PHASE_ERROR_SIGN) {
        phaseError -= CSR_R_PHASE_ERROR_SIGN << 1;
    }
    return phaseError;
}

static void
clockAdjustReport(uint32_t csr)
{
    uint32_t aux = stableRegister(GPIO_IDX_MARBLE_VCXO_PLL_AUX);
    uint32_t hwPPS = stableRegister(GPIO_IDX_MARBLE_VCXO_HW_PPS);
    printf("PLL ");
    if (csr & CSR_R_PLL_ENABLED) {
        int jitter = (aux & AUX_JITTER_MASK) >> AUX_JITTER_SHIFT;
        int i = jitter >> 2;
        int f = ((jitter & 0x3) * 100) >> 2;
        printf("%slocked. Phase diff:%2d Jitter:%d.%02d%s",
                                    (csr & CSR_R_LOCKED) ? "" : "un",
                                    phaseError(csr),
                                    i, f,
                                    (csr & CSR_R_JITTER_IS_HIGH) ? "(HI)" : "");
    }
    else {
        printf("disabled.");
    }
    printf(" DAC:%d ", (int16_t)(aux & AUX_DAC_MASK));
    if (hwPPS & HW_PPS_VALID) {
        printf("HW:%d", hwPPS & ~HW_PPS_STATUS_MASK);
    }
    else {
        printf("PPS Invalid");
    }
    printf("\n");
}

void
clockAdjustScan(void)
{
    static int firstTime = 1, hwWasValid = ~0;

    if (debugFlags & DEBUGFLAG_CLOCKADJUST_SHOW) {
        uint32_t csr = stableRegister(GPIO_IDX_MARBLE_VCXO_PLL_CSR);
        static uint32_t ocsr;
        if (firstTime) {
            firstTime = 0;
        }
        else {
            uint32_t hwIsValid = csr & CSR_R_HW_PPS_VALID;
            if (hwIsValid != hwWasValid) {
                printf("HW PPS %svalid.\n", hwIsValid ? "" : "in");
                hwWasValid = hwIsValid;
            }
            if ((csr^ocsr) & ((csr&CSR_R_PLL_ENABLED) ? CSR_R_DAC_UPDATE_TOGGLE
                                                      : CSR_R_HW_PPS_TOGGLE)) {
                clockAdjustReport(csr);
            }
        }
        ocsr = csr;
    }
    else {
        firstTime = 1;
        hwWasValid = ~0;
    }
}

void
clockAdjustSetDAC(int dacSelect, int dacValue)
{
    if (dacValue == DAC_VALUE_CLOSE_LOOP) {
        GPIO_WRITE(GPIO_IDX_MARBLE_VCXO_PLL_CSR, CSR_W_ENABLE);
    }
    else {
        uint32_t csr = GPIO_READ(GPIO_IDX_MARBLE_VCXO_PLL_CSR);
        if (csr & CSR_R_PLL_ENABLED) {
            GPIO_WRITE(GPIO_IDX_MARBLE_VCXO_PLL_CSR, CSR_W_DISABLE);
        }
        GPIO_WRITE(GPIO_IDX_MARBLE_VCXO_PLL_CSR, CSR_W_SET_DAC |
                                                (dacSelect ? CSR_W_VCXO20 : 0) |                                                (dacValue & CSR_W_DAC_MASK));
    }
}

int
clockAdjustGetDAC(void)
{
    uint32_t aux = stableRegister(GPIO_IDX_MARBLE_VCXO_PLL_AUX);
    return (int16_t)(aux & AUX_DAC_MASK);
}

static void
ppsPresenceReport(const char *type, int present, const char *end)
{
    printf("%s PPS %ssent.%s", type, present ? "pre" : "ab", end);
}

void
clockAdjustShow(void)
{
    uint32_t hwPPS = stableRegister(GPIO_IDX_MARBLE_VCXO_HW_PPS);
    ppsPresenceReport("Primary", hwPPS & HW_PPS_PRIMARY_VALID, "  ");
    ppsPresenceReport("Secondary", hwPPS & HW_PPS_SECONDARY_VALID, "  ");
    ppsPresenceReport("Fabric", hwPPS & HW_PPS_TERTIARY_VALID, "\n");
    clockAdjustReport(stableRegister(GPIO_IDX_MARBLE_VCXO_PLL_CSR));
}
