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
 * Route EVG/EVG I/O
 */
#include <stdio.h>
#include <string.h>
#include "gpio.h"
#include "iicFPGA.h"
#include "ioSelect.h"
#include "mgt.h"
#include "systemParameters.h"
#include "util.h"

#define FMC_NAME "RF-IN"

#define CSR_W_SET_FMC_IS_PRESENT    0x200
#define CSR_W_SET_SET_IS_EVG        0x100
#define CSR_RW_FMC_IS_PRESENT       0x2
#define CSR_RW_IS_EVG               0x1

static void
ioSelectShow(void)
{
    int status = ioSelectStatus();
    if (status & CSR_RW_IS_EVG) {
        printf("Operating as Event Generator.\n");
        printf("Obtaining PPS and hardware inputs from %s.\n",
                    (status & CSR_RW_FMC_IS_PRESENT) ? "FMC RF-IN" : "PMOD-IO");
    }
}

void
ioSelectInit(void)
{
    const char *fmcName = iicFPGAgetNameString(0);
    GPIO_WRITE(GPIO_IDX_IO_SELECT, CSR_W_SET_SET_IS_EVG |
                              (systemParameters.ntpServer ? CSR_RW_IS_EVG: 0));
    if (strcmp(fmcName, FMC_NAME) == 0) {
        GPIO_WRITE(GPIO_IDX_IO_SELECT, CSR_W_SET_FMC_IS_PRESENT |
                                                         CSR_RW_FMC_IS_PRESENT);
    }
    else {
        GPIO_WRITE(GPIO_IDX_IO_SELECT, CSR_W_SET_FMC_IS_PRESENT | 0);
        if (*fmcName != '\0') {
            printf("Warning -- FMC slot 1 module (%s) is not \""FMC_NAME"\".\n",
                                                                       fmcName);
        }
    }
    ioSelectShow();
}

int
ioSelectStatus(void)
{
    return GPIO_READ(GPIO_IDX_IO_SELECT);
}
