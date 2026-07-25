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

#define CSR_W_STOP_ADC      0x1
#define CSR_W_START_ADC     0x2
#define CSR_W_ADS7253_CLK   0x4
#define CSR_W_ADS7253_CS    0x8
#define CSR_W_ADS7253_DIN   0x10
#define CSR_W_LMK01801_CLK  0x20
#define CSR_W_LMK01801_LE   0x40
#define CSR_W_LMK01801_DATA 0x80
#define CSR_R_ADC_STOPPED   0x1
#define CSR_R_ADS7253_DOUTA 0x2
#define CSR_R_ADS7253_DOUTB 0x4

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
    int b;
    uint32_t r, w;
    uint32_t aVal = 0;
    w = CSR_W_ADS7253_CS | CSR_W_ADS7253_CLK;
    GPIO_WRITE(GPIO_IDX_RFIN_CONTROL, w);
    for (b = 0 ; b < 16 ; b++) {
        w = CSR_W_ADS7253_CS | ((wVal & 0x8000) ? CSR_W_ADS7253_DIN : 0);
        wVal <<= 1;
        GPIO_WRITE(GPIO_IDX_RFIN_CONTROL, w | CSR_W_ADS7253_CLK);
        r = GPIO_READ(GPIO_IDX_RFIN_CONTROL);
        aVal = (aVal << 1) | ((r & CSR_R_ADS7253_DOUTA) ? 1 : 0);
        GPIO_WRITE(GPIO_IDX_RFIN_CONTROL, w);
    }
    for (b = 0 ; b < 32 ; b++) {
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
 * Read RF signal level
 * Note that the second ADC channel reads the level of the first RF input (!!).
 */
int
ospreyRFINreadADS7253(int i)
{
    uint32_t r = GPIO_READ(GPIO_IDX_RFIN_CONTROL);
    if (i) {
        return r >> 16;
    }
    return r & 0xFFFF;
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
    GPIO_WRITE(GPIO_IDX_RFIN_CONTROL, 0);
    GPIO_WRITE(GPIO_IDX_RFIN_CONTROL, CSR_W_LMK01801_LE);
    GPIO_WRITE(GPIO_IDX_RFIN_CONTROL, 0);
}

int ospreyEFINlmk01801Set(unsigned fmc, unsigned value)
{
    if(fmc!=1)
      return -1;
    lmk01801writeRegister(value);
    return 0;
}

/*
 * Configure LMK01801 clock distribution
 *  For now:
 *   CLK0 input:
 *     CLK0_M2C -- LMK01801 CLK0  -- divide by 1
 *     GBTCLK1  -- LMK01801 CLK4  -- divide by 1
 *   CLK1 input:
 *     GBTCLK0  -- LMK01801 CLK8  -- divide by 1
 *     CLK1_M2C -- LMK01801 CLK12 -- divide by 1 (J20 diagnostic output too)
 */
static void
lmk01801init(void)
{
    // See https://www.ti.com/lit/ds/symlink/lmk01801.pdf
    // also scripts/lmk01801.py for help constructing and unpacking register values

    /* Unlock settings */
    lmk01801writeRegister(0x000005EF);

    // setup for pass through (divide by 1, no delays, no sync. functions)

    /* R0 -- reset */
    lmk01801writeRegister(0x48003010);

    /* R0
      RESET = 0
      POWERDOWN = 0
      CLKout0_3_PD = 0
      CLKout4_7_PD = 0
      CLKout8_11_PD = 0
      CLKout12_13_PD = 0
      CLKin0_BUF_TYPE = 0
      CLKin1_BUF_TYPE = 0
      CLKin0_DIV = 1
      CLKin0_MUX = 0
      CLKin1_DIV = 1
      CLKin1_MUX = 0
     */
    lmk01801writeRegister(0x48087000);

    /* R1
      CLKout0_TYPE = 1
      CLKout1_TYPE = 0
      CLKout2_TYPE = 0
      CLKout3_TYPE = 0
      CLKout4_TYPE = 1
      CLKout5_TYPE = 0
      CLKout6_TYPE = 0
      CLKout7_TYPE = 0
     */
    lmk01801writeRegister(0x00010011);

    /* R2
      CLKout8_TYPE = 1
      CLKout9_TYPE = 0
      CLKout10_TYPE = 0
      CLKout11_TYPE = 0
      CLKout12_TYPE = 1
      CLKout13_TYPE = 12
     */
    lmk01801writeRegister(0x0C100012);

    /* R3
      CLKout12_13_ADLY = 0
      CLKout12_13_HS = 0
      SYNC1_QUAL = 0
      SYNC0_POL_INV = 0
      SYNC1_POL_INV = 0
      NO_SYNC_CLKout0_3 = 1
      NO_SYNC_CLKout4_7 = 1
      NO_SYNC_CLKout8_11 = 1
      NO_SYNC_CLKout12_13 = 1
      CLKout0_3_OFFSET_PD = 1
      CLKout4_7_OFFSET_PD = 1
      CLKout8_11_OFFSET_PD = 1
      SYNC0_FAST = 0
      SYNC1_FAST = 0
      SYNC0_AUTO = 0
      SYNC1_AUTO = 0
     */
    lmk01801writeRegister(0x107F0003);

    /* R4
      CLKout12_13_DDLY = 0
     */
    lmk01801writeRegister(0x00000004);

    /* R5
      CLKout0_3_DIV = 1
      CLKout4_7_DIV = 1
      CLKout8_11_DIV = 1
      CLKout12_ADLY_SEL = 0
      CLKout13_ADLY_SEL = 0
      CLKout12_13_DIV = 1
     */
    lmk01801writeRegister(0x00020495);

    /* Lock settings */
    lmk01801writeRegister(0x000005FF);
}

///////////////////////////////////////////////////////////////////////////////
void
ospreyRFINinit(void)
{
    int cfr;
    GPIO_WRITE(GPIO_IDX_RFIN_CONTROL, CSR_W_STOP_ADC);
    while ((GPIO_READ(GPIO_IDX_RFIN_CONTROL) & CSR_R_ADC_STOPPED) == 0) {
        continue;
    }
    ads7253writeRegister(ADS7253_CMD_W_CFR, ADS7253_CFR_REF_SEL);
    cfr = ads7253readRegister(ADS7253_CMD_R_CFR);
    GPIO_WRITE(GPIO_IDX_RFIN_CONTROL, CSR_W_START_ADC);
    if (cfr != 0x0040) {
        printf("WARNING -- RF-IN ADS7253 CFR 0x%04X (expect 0x0040).\n", cfr);
    }
    lmk01801init();
}
