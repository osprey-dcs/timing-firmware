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

#ifndef _UTIL_H_
#define _UTIL_H_

#include "xil_printf.h"
#define printf xil_printf

/*
 * Control diagnostic output
 */
#define DEBUGFLAG_EPICS_WRITE           0x1
#define DEBUGFLAG_EPICS_READ            0x2
#define DEBUGFLAG_TFTP                  0x4
#define DEBUGFLAG_MGT                   0x10
#define DEBUGFLAG_EVG                   0x20
#define DEBUGFLAG_EVR                   0x40
#define DEBUGFLAG_CLOCKADJUST_SHOW      0x1000
#define DEBUGFLAG_NTP                   0x8000
#define DEBUGFLAG_IIC_FPGA_SCAN         0x10000
#define DEBUGFLAG_MGT_STATUS_SHOW       0x20000
#define DEBUGFLAG_FLASH_SHOW            0x40000
#define DEBUGFLAG_MGTCLKSWITCHSHOW      0x80000
#define DEBUGFLAG_PMOD1_IS_GPS          0x100000
extern int debugFlags;

#define ntohl(x) __builtin_bswap32(x)
#define htonl(x) __builtin_bswap32(x)
#define ntohs(x) __builtin_bswap16(x)
#define htons(x) __builtin_bswap16(x)

void microsecondSpin(int microseconds);
uint32_t fetchRegister(int idx);
void showIPv4address(const char *name, uint32_t address);
void resetFPGA(int bootAlternateImage);
void criticalWarning(const char *msg);

#endif /* _UTIL_H_ */
