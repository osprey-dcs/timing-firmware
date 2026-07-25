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
 */
#include <stdio.h>
#include <stdint.h>
#include "iicFPGA.h"
#include "si570.h"
#include "util.h"

static void
writeRegister(int reg, int val)
{
    unsigned char buf[2];
    buf[0] = reg;
    buf[1] = val;
    iicFPGAwrite(IIC_FPGA_IDX_SI570, buf, 2);
    if (debugFlags & DEBUGFLAG_SI570) {
        printf("SI570 R%d <- %02X\n", reg, val);
    }
}

static int
readRegister(int reg)
{
    unsigned char buf[1];
    iicFPGAread(IIC_FPGA_IDX_SI570, reg, buf, 1);
    if (debugFlags & DEBUGFLAG_SI570) {
        printf("SI570 R%d -> %02X\n", reg, buf[0]);
    }
    return buf[0];
}

int
si570getR7_9(void)
{
    int r;
    uint32_t v = 0;
    for (r = 7 ; r <= 9 ; r++) {
        v = (v << 8) | readRegister(r);
    }
    return v;
}

int
si570getR10_12(void)
{
    int r;
    uint32_t v = 0;
    for (r = 10 ; r <= 12 ; r++) {
        v = (v << 8) | readRegister(r);
    }
    return v;
}

void
si570setR7_9(int r7_9)
{
    int r;
    for (r = 9 ; r >= 7 ; r--) {
        writeRegister(r, r7_9 & 0xFF);
        r7_9 >>= 8;
    }
}

void
si570setR10_12(int r10_12)
{
    int r;
    for (r = 12 ; r >= 10 ; r--) {
        writeRegister(r, r10_12 & 0xFF);
        r10_12 >>= 8;
    }
}

void
si570setR135(int r135)
{
    writeRegister(135, r135);
}

void
si570setR137(int r137)
{
    writeRegister(137, r137);
    /*
     * Must assert 'New Frequency' bit within 10 ms of unfreezing DCO.
     */
    if (r137 == 0) {
        si570setR135(0x40);
    }
}
