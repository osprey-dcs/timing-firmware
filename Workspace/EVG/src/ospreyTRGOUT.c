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
#include "ospreyTRGOUT.h"
#include "util.h"

// R/O
#define JTR_PRESENT 0x80000000
#define JTR_LOL     0x00000800
#define JTR_LOS     0x00000400
#define JTR_INTR    0x00000200
#define JTR_MISO    0x00000100
// R/W
#define JTR_LVL_DIS 0x00000020
#define JTR_CLK_DIS 0x00000010
#define JTR_RST     0x00000008
#define JTR_CSn     0x00000004
#define JTR_SCLK    0x00000002
#define JTR_MOSI    0x00000001

static
uint32_t outDis = JTR_CLK_DIS;

static
uint8_t si539xShift(unsigned ch, uint16_t val)
{
    uint32_t basev = outDis;

    GPIO_WRITE(GPIO_IDX_TRGOUT_JTR1_SPI+ch, basev|JTR_CSn); // CSn, ~SCLK
    microsecondSpin(1);

    uint16_t out=0;
    for(unsigned i=0; i<16; i++, val<<=1) {
        uint32_t v = basev | ((val&0x8000) ? JTR_MOSI : 0); // ~CSn, ~SCLK, setup MOSI and MISO
        GPIO_WRITE(GPIO_IDX_TRGOUT_JTR1_SPI+ch, v);
        microsecondSpin(1);
        GPIO_WRITE(GPIO_IDX_TRGOUT_JTR1_SPI+ch, v|JTR_SCLK); // ~CSn, SCLK, sample MOSI and MISO
        out<<=1;
        out |= !!(GPIO_READ(GPIO_IDX_TRGOUT_JTR1_SPI+ch) & JTR_MISO);
        microsecondSpin(1);
    }

    GPIO_WRITE(GPIO_IDX_TRGOUT_JTR1_SPI+ch, basev); // ~CSn, ~SCLK
    microsecondSpin(1);
    GPIO_WRITE(GPIO_IDX_TRGOUT_JTR1_SPI+ch, basev|JTR_CSn); // CSn, ~SCLK
    microsecondSpin(2);
    return out;
}

void si539xWrite(unsigned ch, uint8_t addr, uint8_t val)
{
    (void)si539xShift(ch, 0x0000 | addr); // Set Addr
    (void)si539xShift(ch, 0x4000 | val); // Write Data
}

uint8_t si539xRead(unsigned ch, uint8_t addr)
{
    (void)si539xShift(ch, 0x0000 | addr); // Set Addr
    return si539xShift(ch, 0x8000); // Read Data
}

static
void ospreyTRGOUTinitChannel(unsigned ch)
{
    printf("Setup si539x %u\n", ch);

    // enable level shifters
    GPIO_WRITE(GPIO_IDX_TRGOUT_JTR1_SPI+ch,
               JTR_CLK_DIS|JTR_RST|JTR_CSn);
    microsecondSpin(1);
    // clear reset (inverted in logic)
    GPIO_WRITE(GPIO_IDX_TRGOUT_JTR1_SPI+ch,
               JTR_CLK_DIS|JTR_CSn);
    microsecondSpin(1);
    // leave clock outputs disabled.
    // SCLK idle low, de-selected

    si539xWrite(ch, 0x01, 0); // select page 0
    // read ID registers
    for(unsigned addr=0x2; addr<=0xa; addr++) {
        printf("  0x00%02x %08x\n", addr, si539xRead(ch, addr));
    }
}

void ospreyTRGOUTinit()
{
    if(!(GPIO_READ(GPIO_IDX_TRGOUT_JTR1_SPI)&JTR_PRESENT))
        return; // FMC2 no present
    ospreyTRGOUTinitChannel(0);
    ospreyTRGOUTinitChannel(1);
}

uint32_t osreyTRGOUTRead(uint32_t addr) { return 0; }
void osreyTRGOUTWrite(uint32_t addr) {}
