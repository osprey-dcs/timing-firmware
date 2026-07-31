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
 * Multi-Gigabit Transceiver control
 */

#include <stdio.h>
#include <xparameters.h>
#include "eyescan.h"
#include "gpio.h"
#include "mgt.h"
#include "util.h"

#define CSR_W_DRP_ENABLE        0x80000000
#define CSR_W_DRP_WRITE         0x40000000
#define CSR_W_LOL_CLEAR         0x20000000
#define CSR_W_SEL_SHIFT         27
#define CSR_W_DRP_ADDR_SHIFT    16
#define CSR_RW_DRP_DATA_MASK    0xFFFF
//                              0x18000000
#define CSR_W_SEL_MASK          (0x7 << CSR_W_SEL_SHIFT)
#define CSR_W_LOOPBACK          0x04000000
#define CSR_W_LANE_RXSLIDE      0x02000000
#define CSR_W_TX_LANE_POWERDOWN 0x01000000
#define CSR_W_RX_LANE_POWERDOWN 0x00800000
#define CSR_W_RX_LANE_RESET     0x00400000
#define CSR_W_TX_SOFT_RESET     0x00200000
#define CSR_W_RX_SOFT_RESET     0x00100000

#define CSR_R_DRP_BUSY                  0x80000000
#define CSR_R_LOL_LATCHED               0x20000000
#define CSR_R_QPLL1_LOCKED              0x08000000
#define CSR_R_QPLL1_REFCLK_LOST         0x04000000
#define CSR_R_QPLL0_LOCKED              0x02000000
#define CSR_R_QPLL0_REFCLK_LOST         0x01000000
#define CSR_R_TX_LANE_RESET_DONE        0x00080000
#define CSR_R_RX_LANE_RESET_DONE        0x00040000
#define CSR_R_RX_LANE_FSM_RESET_DONE    0x00020000
#define CSR_R_TX_LANE_FSM_RESET_DONE    0x00010000

#define PLLS_LOCKED    (CSR_R_QPLL1_LOCKED | CSR_R_QPLL0_LOCKED)
#define FSM_RESET_DONE (CSR_R_RX_FSM_RESET_DONE | CSR_R_TX_FSM_RESET_DONE)

#define LOOBPACK_NONE       0
#define LOOBPACK_NEAR_PCS   1
#define LOOBPACK_NEAR_PMA   2
#define LOOBPACK_FAR_PMA    4
#define LOOBPACK_FAR_PCS    6

/*
 * For now, start by assuming that all lanes are active
 */
static uint32_t activeRx = ((1UL << CFG_MGT_COUNT) - 1);

static void
mgtShowLinkStatus(void)
{
    printf("MGT links up: %02X\n", GPIO_READ(GPIO_IDX_LINK_STATUS));
}

void
mgtShowStatus(void)
{
    int mgtIndex;
    uint32_t csr;
    for(mgtIndex = 0 ; mgtIndex < CFG_MGT_COUNT ; mgtIndex++) {
        GPIO_WRITE(GPIO_IDX_MGT_CSR, mgtIndex << CSR_W_SEL_SHIFT);
        csr = GPIO_READ(GPIO_IDX_MGT_CSR);
        printf("MGT %d: %04X:%04X\n", mgtIndex, csr >> 16, csr & 0xFFFF);
    }
    mgtShowLinkStatus();
}

void
mgtInit(void)
{
    uint32_t csr, then = microsecondsSinceBoot();
    for (;;) {
        csr = GPIO_READ(GPIO_IDX_MGT_CSR);
        if ((csr & PLLS_LOCKED) == PLLS_LOCKED) {
            break;
        }
        if ((microsecondsSinceBoot() - then) > 1000000) {
            printf("Warning -- QPLL unlocked: %08X\n", csr);
            break;
        }
    }
    GPIO_WRITE(GPIO_IDX_MGT_CSR, CSR_W_RX_LANE_RESET |
                                 CSR_W_RX_LANE_POWERDOWN | 0);
    GPIO_WRITE(GPIO_IDX_MGT_CSR, CSR_W_TX_SOFT_RESET | CSR_W_RX_SOFT_RESET);
    microsecondSpin(100);
    eyescanInit();

    /*
     * Enable all transmitters and first receiver
     * FIXME -- transmitters should be enabled only on event generator.
     * FIXME -- receiver operation seems flakey when any are powered down (!!!)
     */
    mgtSetActiveTx((1UL << CFG_MGT_COUNT) - 1);
    mgtSetActiveRx((1UL << CFG_MGT_COUNT) - 1);

    /*
     * Must reset PMA after enabling eye scan hardware
     */
    GPIO_WRITE(GPIO_IDX_MGT_CSR, CSR_W_RX_LANE_RESET|((1UL<<CFG_MGT_COUNT)-1));
    microsecondSpin(1);
    // deassert resets, attempt to clear ref. clock loss-of-lock latch
    GPIO_WRITE(GPIO_IDX_MGT_CSR, CSR_W_RX_LANE_RESET | CSR_W_LOL_CLEAR);
}

/*
 * Report link status changes
 */
void
mgtCrank(void)
{
    unsigned int isUp;
    static unsigned int wasUp = ~0;
    uint32_t now = microsecondsSinceBoot();
    static uint32_t then;

    if(GPIO_READ(GPIO_IDX_MGT_CSR) & CSR_R_LOL_LATCHED) {
        if(debugFlags & DEBUGFLAG_MGT)
            printf("MGT ref. clock lost.  Resetting all channels.\n");
        mgtInit();
    }

    if ((now - then) < 100000) {
        return;
    }
    isUp = GPIO_READ(GPIO_IDX_LINK_STATUS) & activeRx;
    if ((debugFlags & DEBUGFLAG_MGT) && (isUp != wasUp)) {
        mgtShowLinkStatus();
    }
    wasUp = isUp;
    then = now;
}

uint32_t
mgtFetchSysmon(int index)
{
    switch (index) {
    case 0: return GPIO_READ(GPIO_IDX_LINK_STATUS);
    case 1: return GPIO_READ(GPIO_IDX_MGT_CSR);
    default: return 0;
    }
}

void
mgtSetLoopback(int mgtIndex, int loopback)
{
    if ((mgtIndex < 0) || (mgtIndex >= CFG_MGT_COUNT)) {
        return;
    }
    GPIO_WRITE(GPIO_IDX_MGT_CSR, CSR_W_LOOPBACK | (mgtIndex << 3) |
                                                              (loopback & 0x7));
}

void
mgtSetActiveRx(uint32_t active)
{
    uint32_t idleRx;
    /*
     * First channel (EVR) is always active
     */
    activeRx = (active | 0x1) & ((1UL << CFG_MGT_COUNT) - 1);
    idleRx = ~activeRx & ((1UL << CFG_MGT_COUNT) - 1);
    GPIO_WRITE(GPIO_IDX_MGT_CSR, CSR_W_RX_LANE_POWERDOWN | idleRx);
}

void
mgtSetActiveTx(uint32_t active)
{
    uint32_t idleTx;
    idleTx = ~active & ((1UL << CFG_MGT_COUNT) - 1);
    GPIO_WRITE(GPIO_IDX_MGT_CSR, CSR_W_TX_LANE_POWERDOWN | idleTx);
}

void
mgtDRPwrite(int mgtIndex, int drpAddress, int value)
{
    if ((mgtIndex < 0) || (mgtIndex >= CFG_MGT_COUNT)) {
        return;
    }
    if (debugFlags & DEBUGFLAG_MGT) {
        printf("MGT %d %03X <- %04X\n", mgtIndex, drpAddress, value);
    }
    GPIO_WRITE(GPIO_IDX_MGT_CSR, CSR_W_DRP_ENABLE | CSR_W_DRP_WRITE |
                                        (mgtIndex << CSR_W_SEL_SHIFT) |
                                        (drpAddress << CSR_W_DRP_ADDR_SHIFT) |
                                        (value & CSR_RW_DRP_DATA_MASK));
    while (GPIO_READ(GPIO_IDX_MGT_CSR) & CSR_R_DRP_BUSY) continue;
}

int
mgtDRPread(int mgtIndex, int drpAddress)
{
    uint32_t csr;
    if ((mgtIndex < 0) || (mgtIndex >= CFG_MGT_COUNT)) {
        return -1;
    }
    GPIO_WRITE(GPIO_IDX_MGT_CSR, CSR_W_DRP_ENABLE |
                                        (mgtIndex << CSR_W_SEL_SHIFT) |
                                        (drpAddress << CSR_W_DRP_ADDR_SHIFT));
    while ((csr = GPIO_READ(GPIO_IDX_MGT_CSR)) & CSR_R_DRP_BUSY) continue;
    if (debugFlags & DEBUGFLAG_MGT) {
        printf("MGT %d %03X -> %04X\n", mgtIndex, drpAddress,
                                                    csr & CSR_RW_DRP_DATA_MASK);
    }
    return csr & CSR_RW_DRP_DATA_MASK;
}
