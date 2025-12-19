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

/*
 * General-purpose I/O registers
 * Use to generate Verilog parameter statements -- all GPIO_IDX
 * macros must be base ten constants.
 */

#ifndef _GPIO_H_
#define _GPIO_H_

#include <xil_io.h>

#define GPIO_IDX_FIRMWARE_DATE              0 // Firmware build POSIX date (R)
#define GPIO_IDX_MICROSECONDS_SINCE_BOOT    1 // 1 MHz counter (R)
#define GPIO_IDX_SECONDS_SINCE_BOOT         2 // 1 Hz counter (R)
#define GPIO_IDX_FREQUENCY_COUNTERS         3 // Clock rate measurement
#define GPIO_IDX_MMC_IO                     4 // Microcontroller communication
#define GPIO_IDX_MGT_CSR                    5 // Multi-gigabit transceiver CSR
#define GPIO_IDX_LINK_STATUS                6 // MGT link status
#define GPIO_IDX_LOCAL_PPS_CSR              7 // Local PPS source
#define GPIO_IDX_MARBLE_VCXO_PLL_CSR        8 // VCXO clock adjust status
#define GPIO_IDX_MARBLE_VCXO_PLL_AUX        9 // More VCXO clock adjust status
#define GPIO_IDX_MARBLE_VCXO_HW_PPS        10 // Hardware PPS status
#define GPIO_IDX_IO_SELECT                 11 // Hardware configuration

#define GPIO_IDX_COUNT                     32 // Number of GPIO registers

#define GPIO_READ(r) Xil_In32(XPAR_GENERIC_REG_BASEADDR+((r)*4))
#define GPIO_WRITE(r,v) Xil_Out32(XPAR_GENERIC_REG_BASEADDR+((r)*4),(v))

#define microsecondsSinceBoot() GPIO_READ(GPIO_IDX_MICROSECONDS_SINCE_BOOT)

#include "config.h"

#endif /* _GPIO_H_ */
