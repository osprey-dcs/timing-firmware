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
#include <ospreyEVG.h>
#include <ospreyUDP.h>
#include "bootFlash.h"
#include "clockAdjust.h"
#include "console.h"
#include "epics.h"
#include "gpio.h"
#include "iicFPGA.h"
#include "ioSelect.h"
#include "mgt.h"
#include "mgtClkSwitch.h"
#include "mmcMailbox.h"
#include "ospreyRFIN.h"
#include "platform.h"
#include "softwareBuildDate.h"
#include "si570.h"
#include "systemParameters.h"
#include "tftp.h"
#include "util.h"
#include "xadc.h"

#include <ospreyEVR.h>
static void
checkEVR(void)
{
    int code;
    uint32_t seconds, ticks;
    static int firstTime = 1;
    if (firstTime) {
        firstTime = 0;
        ospreyEVRSetEventAction(125, OSPREY_EVR_ACTION_WRITE_FIFO);
    }
    if ((code = ospreyEVRGetFifoEvent(&seconds, &ticks)) != 0) {
        printf("%X %3d %10u%10u\n", ospreyEVRStatus(), code, seconds, ticks);
    }
}

int
main(void)
{
    init_platform();
    printf("Firmware build: %u\n", GPIO_READ(GPIO_IDX_FIRMWARE_DATE));
    printf("Software build: %u\n", SOFTWARE_BUILD_DATE);
    bootFlashInit(XPAR_MARBLEBOOTFLASH_S_AXI_LITE_BASEADDR);
    mmcMailboxInit();
    systemParametersInit();
    ospreyUDPregisterInterface(XPAR_OSPREYUDP_S_AXI_LITE_BASEADDR,
                               networkConfig.ipv4address,
                               systemParameters.gateway,
                               systemParameters.netmask,
                               networkConfig.macAddress);
    consoleInit();
    iicFPGAinit();
    ioSelectInit();
    ospreyRFINinit();
    mgtClkSwitchInit();

    xadcInit();
    mgtInit();
    tftpInit();
    epicsInit();
    ospreyEVGInit(XPAR_OSPREYEVG_S_AXI_BASEADDR);
    ospreyEVRInit(XPAR_OSPREYEVR_S_AXI_BASEADDR);
    printf("Boot complete @%u\n", (unsigned)microsecondsSinceBoot());
    for (;;) {
        clockAdjustScan();
        mgtCrank();
        consoleCrank();
        ospreyUDPcrank();
        //checkEVR();
    }
    cleanup_platform();
    return 0;
}
