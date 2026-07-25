/*
 * MIT License
 *
 * Copyright (c) 2022 Osprey DCS
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
 * Marble SI570 MGT clock reference
 *
 * Must lookup reference frequency and address by part number
 *   https://tools.skyworksinc.com/TimingUtility/timing-part-number-search-results.aspx
 *
 * Marble 1.4.x has 570NBB001808DGR
 *   I2C address: 0x55
 *   Ref. frequency: 270 MHz
 *   Temperature Stability: 20 PPM
 */
#include <stdio.h>
#include <stdint.h>
#include "iicFPGA.h"
#include "si570.h"
#include "util.h"

static void
writeRegister(unsigned reg, uint8_t val)
{
    uint8_t buf[2];
    buf[0] = reg;
    buf[1] = val;
    iicFPGAwrite(IIC_FPGA_IDX_SI570, buf, 2);
    if (debugFlags & DEBUGFLAG_SI570) {
        printf("SI570 R%d <- %02X\n", reg, val);
    }
}

static int
readRegister(unsigned reg)
{
    uint8_t buf[1];
    iicFPGAread(IIC_FPGA_IDX_SI570, reg, buf, 1);
    if (debugFlags & DEBUGFLAG_SI570) {
        printf("SI570 R%d -> %02X\n", reg, buf[0]);
    }
    return buf[0];
}

static uint32_t
si570getR7_9(void)
{
    int r;
    uint32_t v = 0;
    for (r = 7 ; r <= 9 ; r++) {
        v = (v << 8) | readRegister(r);
    }
    return v;
}

static uint32_t
si570getR10_12(void)
{
    uint32_t v = 0;
    for (unsigned r = 10 ; r <= 12 ; r++) {
        v = (v << 8) | readRegister(r);
    }
    return v;
}

static void
si570setR7_9(uint32_t r7_9)
{
    for (unsigned r = 9 ; r >= 7 ; r--) {
        writeRegister(r, r7_9 & 0xFF);
        r7_9 >>= 8;
    }
}

static void
si570setR10_12(uint32_t r10_12)
{
    for (unsigned r = 12 ; r >= 10 ; r--) {
        writeRegister(r, r10_12 & 0xFF);
        r10_12 >>= 8;
    }
}

static
uint32_t si570Cal[2];

uint32_t si570Read(int addr)
{
    switch(addr) {
    case 0: return si570getR7_9();
    case 1: return si570getR10_12();
    case 2: return si570Cal[0];
    case 3: return si570Cal[1];
    default: return 0xdeadbeef;
    }
}

void si570Write(int addr, uint32_t val)
{
    static uint32_t scratch7_9 = 0;
    switch(addr) {
    case 0: scratch7_9 = val; break;
    case 1:
        // programming sequence for arbitrary freq (not small jump) from si570 datasheet,

        writeRegister(137, 0x10); // Freeze DCO

        si570setR7_9(scratch7_9);
        si570setR10_12(val);

        writeRegister(137, 0x00); // Un-Freeze DCO
        writeRegister(135, 0x40); // NewFreq
        break;
    }
}

void si570Init(void)
{
    /* The Si570 is an odd one.  On reset it reverts to a specified default output frequency,
     * which can not be introspected.
     * To compute new outputs, we first have to read back the burned in default settings
     * which achieve this specified output.
     * The datasheet is emphatic that these values can vary from part to part, so no cheating!
     *
     * f_out = f_xtal * RFREQ / HSDIV / N1
     */
    writeRegister(135, 0x01); // RECALL defaults
    do {
        microsecondSpin(1000);
    } while(readRegister(135)&0x01);
    si570Cal[0] = si570getR7_9();
    si570Cal[1] = si570getR10_12();

    printf("Si570 read calib: 0x%06x%06x\n", si570Cal[0], si570Cal[1]);
}
