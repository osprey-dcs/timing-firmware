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
#include "si570.h"
#include "ioSelect.h"
#include "mgt.h"
#include "mgtClkSwitch.h"
#include "mmcMailbox.h"
#include "ospreyRFIN.h"
#include "ospreyTRGOUT.h"
#include "ospreyEVR.h"
#include "platform.h"
#include "softwareBuildDate.h"
#include "si570.h"
#include "systemParameters.h"
#include "tftp.h"
#include "util.h"
#include "xadc.h"

static
void outputRavel(void)
{
    /* Physical output order
     *  0-3 - PMOD J12 OUT1-4
     *  4-7 - PMOD J13 OUT1-4
     * 8-23 - FMC2 OUT1-16
     *
     * default output mapping is direct I -> I
     */
    if(ioSelectStatus() & IOSELECT_STATUS_FMC2_IS_PRESENT) {
        printf("FMC2 output ravel\n");
        unsigned logical = 0;
        // remap FMC as 0-15, PMODs as 16-23
        for(unsigned fmc=0; fmc<16; fmc++)
            ospreyEVRRemapOutput(logical++, fmc+8);
        for(unsigned pmod=0; pmod<8; pmod++)
            ospreyEVRRemapOutput(logical++, pmod);
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
    si570Init();
    ioSelectInit();
    ospreyRFINinit();
    ospreyTRGOUTinit();
    mgtClkSwitchInit();

    xadcInit();
    mgtInit();
    tftpInit();
    epicsInit();
    ospreyEVGInit(XPAR_OSPREYEVG_S_AXI_BASEADDR);
    ospreyEVRInit(XPAR_OSPREYEVR_S_AXI_BASEADDR);
    outputRavel();
    printf("Boot complete @%u\n", (unsigned)microsecondsSinceBoot());
    for (;;) {
        epicsCrank();
        clockAdjustScan();
        mgtCrank();
        consoleCrank();
        ospreyUDPcrank();
        ospreyTRGOUTcrank();
    }
    cleanup_platform();
    return 0;
}
