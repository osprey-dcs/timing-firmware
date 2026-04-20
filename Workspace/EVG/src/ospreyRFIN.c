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
#include "ospreyRFIN.h"
#include "gpio.h"
#include "util.h"

#define CSR_W_ADS7253_CLK   0x1
#define CSR_W_ADS7253_CS    0x2
#define CSR_W_ADS7253_DIN   0x4
#define CSR_W_LMK01801_CLK  0x8
#define CSR_W_LMK01801_LE   0x10
#define CSR_W_LMK01801_DATA 0x20
#define CSR_R_ADS7253_DOUTA 0x1
#define CSR_R_ADS7253_DOUTB 0x2

#define ADS7253_CMD_W_CFR         0x8
#define ADS7253_CMD_W_REFDAC_A    0x9
#define ADS7253_CMD_W_REFDAC_B    0xA
#define ADS7253_CMD_R_CFR         0x3
#define ADS7253_CMD_R_REFDAC_A    0x1
#define ADS7253_CMD_R_REFDAC_B    0x2

#define ADS7253_CFR_RD_CLK_MODE     0x800
#define ADS7253_CFR_RD_DATA_LINES   0x400
#define ADS7253_CFR_RD_INPUT_RANGE  0x200
#define ADS7253_CFR_INM_SEL         0x80
#define ADS7253_CFR_REF_SEL         0x40
#define ADS7253_CFR_STANDBY         0x20
#define ADS7253_CFR_RD_DATA_FORMAT  0x10

///////////////////////////////////////////////////////////////////////////////
// ADS7253 dual ADC (RF power measurement

/*
 * Shift a 16 bit value to/from ADS7253 ADC followed by 32 bits of 0 to ADC.
 */
static uint32_t
ads7253shift48(uint32_t wVal)
{
    int bitCount;
    uint32_t r, w;
    uint32_t aVal = 0;
    w = CSR_W_ADS7253_CS | CSR_W_ADS7253_CLK;
    GPIO_WRITE(GPIO_IDX_RFIN_CONTROL, w);
    bitCount = 16;
    while (--bitCount >= 0) {
        w = CSR_W_ADS7253_CS | ((wVal & (1<<bitCount)) ? CSR_W_ADS7253_DIN : 0);
        GPIO_WRITE(GPIO_IDX_RFIN_CONTROL, w | CSR_W_ADS7253_CLK);
        r = GPIO_READ(GPIO_IDX_RFIN_CONTROL);
        aVal = (aVal << 1) | ((r & CSR_R_ADS7253_DOUTA) ? 1 : 0);
        GPIO_WRITE(GPIO_IDX_RFIN_CONTROL, w);
    }
    bitCount = 32;
    while (--bitCount >= 0) {
        GPIO_WRITE(GPIO_IDX_RFIN_CONTROL, CSR_W_ADS7253_CS | CSR_W_ADS7253_CLK);
        GPIO_WRITE(GPIO_IDX_RFIN_CONTROL, CSR_W_ADS7253_CS);
    }
    GPIO_WRITE(GPIO_IDX_RFIN_CONTROL, 0);
    return aVal;
}

static uint32_t
ads7253readRegister(int cmd)
{
    ads7253shift48(cmd << 12);
    return ads7253shift48(0);
}

static void
ads7253writeRegister(int cmd, int value)
{
    /*
     * Need to provide only 32 clocks, but register writes are rare so
     * the overhead of shifting an extra 16 bits is insignificant.
     */
    ads7253shift48((cmd << 12) | (value & 0xFFF));
}

/*
 * Assume that channel B reads are always preceded by a channel A read.
 */
int
ospreyRFINreadADS7253(int i)
{
    int bitCount;
    uint32_t r;
    uint32_t aVal = 0;
    static int bVal;
    
    if (i == 1) return bVal;
    if (i != 0) return -1;
    GPIO_WRITE(GPIO_IDX_RFIN_CONTROL, CSR_W_ADS7253_CS | CSR_W_ADS7253_CLK);
    bitCount = 16;
    while (--bitCount >= 0) {
        GPIO_WRITE(GPIO_IDX_RFIN_CONTROL, CSR_W_ADS7253_CS | CSR_W_ADS7253_CLK);
        GPIO_WRITE(GPIO_IDX_RFIN_CONTROL, CSR_W_ADS7253_CS);
    }
    bitCount = 16;
    while (--bitCount >= 0) {
        GPIO_WRITE(GPIO_IDX_RFIN_CONTROL, CSR_W_ADS7253_CS | CSR_W_ADS7253_CLK);
        r = GPIO_READ(GPIO_IDX_RFIN_CONTROL);
        aVal = (aVal << 1) | ((r & CSR_R_ADS7253_DOUTA) ? 1 : 0);
        bVal = (bVal << 1) | ((r & CSR_R_ADS7253_DOUTB) ? 1 : 0);
        GPIO_WRITE(GPIO_IDX_RFIN_CONTROL, CSR_W_ADS7253_CS);
    }
    GPIO_WRITE(GPIO_IDX_RFIN_CONTROL, 0);
    return aVal;
}

///////////////////////////////////////////////////////////////////////////////
// LMK01801 dual clock divider/buffer

static void
lmk01801writeRegister(uint32_t shiftReg)
{
    int i;
    for (i = 0 ; i < 32 ; i++) {
        uint32_t d = (shiftReg & 0x80000000) ? CSR_W_LMK01801_DATA : 0;
        GPIO_WRITE(GPIO_IDX_RFIN_CONTROL, d);
        GPIO_WRITE(GPIO_IDX_RFIN_CONTROL, d | CSR_W_LMK01801_CLK);
        shiftReg <<= 1;
    }
    GPIO_WRITE(GPIO_IDX_RFIN_CONTROL, CSR_W_LMK01801_LE);
    GPIO_WRITE(GPIO_IDX_RFIN_CONTROL, 0);
}

///////////////////////////////////////////////////////////////////////////////
void
ospreyRFINinit(void)
{
    int cfr;
    ads7253writeRegister(ADS7253_CMD_W_CFR, ADS7253_CFR_REF_SEL);
    cfr = ads7253readRegister(ADS7253_CMD_R_CFR);
    if (cfr != 0x0040) {
        printf("WARNING -- RF-IN ADS7253 CFR %04X.\n", cfr);
    }
}
