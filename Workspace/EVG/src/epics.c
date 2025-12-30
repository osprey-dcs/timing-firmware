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
 * Communicate with EPICS IOC using LBNL FEED protocol
 */
#include <stdio.h>
#include <ospreyEVG.h>
#include <ospreyEVR.h>
#include <ospreyUDP.h>
#include "clockAdjust.h"
#include "config.h"
#include "epics.h"
#include "gpio.h"
#include "iicFPGA.h"
#include "localPPS.h"
#include "mgt.h"
#include "mgtClkSwitch.h"
#include "mmcMailbox.h"
#include "softwareBuildDate.h"
#include "systemParameters.h"
#include "util.h"
#include "xadc.h"

#define LEEP_UDP_PORT 50006
#define ETHERNET_UDP_PAYLOAD_CAPACITY   1472
#define LEEP_BYTES_TO_REG(b) (((b) - 8) / 8)
#define LEEP_REG_TO_BYTES(r) (((r) * 8) + 8)
#define LEEP_REG_CAPACITY LEEP_BYTES_TO_REG(ETHERNET_UDP_PAYLOAD_CAPACITY)
#define LEEP_BITS_READ      0x10000000
#define LEEP_ADDRESS_MASK   0x00FFFFFF

struct LEEPheader{
    char headerChars[8];
};
struct LEEPreg {
    uint32_t bits_addr;
    uint32_t value;
};
struct LEEPpacket {
    struct LEEPheader header;
    struct LEEPreg    regs[LEEP_REG_CAPACITY];
};

#define REG_POWERUP_STATE                   10
#define REG_FIRMWARE_BUILD_DATE             20
#define REG_SOFTWARE_BUILD_DATE             21
#define REG_FPGA_REBOOT                     30
#define REG_SECONDS_SINCE_BOOT              40
#define REG_FMC1_SERIAL_NUMBER              50
#define REG_FMC2_SERIAL_NUMBER              51
#define REG_FMC1_PART_NUMBER                54
#define REG_FMC2_PART_NUMBER                55
#define REG_MARBLE_MGT_REFCLK_SOURCE        80
#define REG_MARBLE_PLL_SET_Y1               86
#define REG_MARBLE_PLL_SET_Y3               87
#define REG_MARBLE_PPS_LOCAL_CSR            88
#define REG_SYSMON_BASE                     100
#define SYSMON_SIZE                         300

#define REG_JSON_ROM_BASE                   0x800
#define REG_JSON_ROM_ALTERNATE_BASE         0x4000
#define REG_JSON_ROM_ALTERNATE_SIZE         0x4000

#define REG_EVG_START                       1000000
#define REG_EVG_COUNT                       100000
#define REG_EVR_START                       1100000
#define REG_EVR_COUNT                       100000

#define RANGE(base, count) (base) ... ((base)+(count)-1)

static int powerUpFlag = 1;

static void
setMgtClkSwitch0(int inputClkIndex)
{
    uint32_t now;
    static uint32_t whenWritten;
    if ((inputClkIndex < 0)
     || (inputClkIndex >= MGT_CLK_SWITCH_INPUT_DISABLE_OUTPUT)) {
        return;
    }
    if (inputClkIndex != systemParameters.mgtClkSwitch0) {
        mgtClkSwitchConnectOutputToInput(MGT_CLK_SWITCH_OUTPUT_MGTCLK0,
                                         inputClkIndex);
        now = GPIO_READ(GPIO_IDX_SECONDS_SINCE_BOOT);
        if ((whenWritten != 0) && ((now - whenWritten) < 300)) {
            return;
        }
        systemParameters.mgtClkSwitch0 = inputClkIndex;
        systemParametersStash();
        whenWritten = now;
    }
}

static void
writeReg(int address, uint32_t value)
{
    if (systemParameters.ntpServer
     && (address >= REG_EVG_START)
     && (address < (REG_EVG_START + REG_EVG_COUNT))) {
        ospreyEVG_FEEDwrite(address - REG_EVG_START, value);
        return;
    }
    if ((address >= REG_EVR_START)
     && (address < (REG_EVR_START + REG_EVR_COUNT))) {
        ospreyEVR_FEEDwrite(address - REG_EVR_START, value);
        return;
    }
    switch(address) {
    case REG_POWERUP_STATE:     if (value == 0)   powerUpFlag = 0;       return;
    case REG_FPGA_REBOOT:       if (value == 100) resetFPGA(0);          return;
    case REG_MARBLE_MGT_REFCLK_SOURCE:  setMgtClkSwitch0(value);         return;
    case REG_MARBLE_PLL_SET_Y1:         clockAdjustSetDAC(0, value);     return;
    case REG_MARBLE_PLL_SET_Y3:         clockAdjustSetDAC(1, value);     return;
    case REG_MARBLE_PPS_LOCAL_CSR:      localPPSenable(value);           return;
    }
}

static uint32_t
readReg(int address)
{
    /*
     * Application-specific registers
     */
    if (systemParameters.ntpServer
     && (address >= REG_EVG_START)
     && (address < (REG_EVG_START + REG_EVG_COUNT))) {
        return ospreyEVG_FEEDread(address - REG_EVG_START);
    }
    if ((address >= REG_EVR_START)
     && (address < (REG_EVR_START + REG_EVR_COUNT))) {
        return ospreyEVR_FEEDread(address - REG_EVR_START);
    }
    switch(address) {
    case REG_POWERUP_STATE:       return powerUpFlag;
    case REG_FIRMWARE_BUILD_DATE: return GPIO_READ(GPIO_IDX_FIRMWARE_DATE);
    case REG_SOFTWARE_BUILD_DATE: return SOFTWARE_BUILD_DATE;
    case REG_SECONDS_SINCE_BOOT:  return GPIO_READ(GPIO_IDX_SECONDS_SINCE_BOOT);
    case REG_FMC1_SERIAL_NUMBER:  return iicFPGAgetSerialNumber(0);
    case REG_FMC2_SERIAL_NUMBER:  return iicFPGAgetSerialNumber(1);
    case REG_FMC1_PART_NUMBER:    return iicFPGAgetPartNumber(0);
    case REG_FMC2_PART_NUMBER:    return iicFPGAgetPartNumber(1);
    case RANGE(REG_SYSMON_BASE, SYSMON_SIZE):
        {
        int offset = address - REG_SYSMON_BASE;
        int bank = offset & 0xE0;
        int index = offset & 0x1F;
        switch (bank) {
        case 0x00:  return xadcFetchSysmon(index);
        case 0x20:  return mmcMailboxFetchSysmon(index);
        case 0x40:  return iicFPGAfetchSysmon(index);
        case 0xC0:  return clockAdjustFetchSysmon(index);
        case 0xE0:  return mgtFetchSysmon(index);
        }
        }
        return 0;
    case REG_MARBLE_MGT_REFCLK_SOURCE: return systemParameters.mgtClkSwitch0;
    case REG_MARBLE_PPS_LOCAL_CSR:     return localPPSstatus();
    }

    /*
     * Generic LEEP registers
     * The baseRegs initializer puts the string in network byte order.
     * Check these addresses last since they're read only at IOC (re)connect.
     */
    union LEEPbaseRegs { char u_c[16]; uint32_t u_l[4]; };
    static const union LEEPbaseRegs baseRegs = {.u_c = "Hello World!\r\n\r\n"};
#   include "JSONrom.h"
#   define JSON_ELEMENT_COUNT ((sizeof config_romx / sizeof config_romx[0]))
    if ((address >= 0) && (address < 3)) {
        return ntohl(baseRegs.u_l[address]);
    }
    else if (address == REG_JSON_ROM_BASE) {
        return 0;
    }
    else if ((address >= REG_JSON_ROM_ALTERNATE_BASE)
          && (address < (REG_JSON_ROM_ALTERNATE_BASE + JSON_ELEMENT_COUNT))) {
        return config_romx[address-REG_JSON_ROM_ALTERNATE_BASE];
    }
    return 0;
}

static void
showClient(int length, uint32_t farAddress, int farPort)
{
    printf("LEEP %d from %d.%d.%d.%d:%d", length, (farAddress >> 24) & 0xFF,
                                                  (farAddress >> 16) & 0xFF,
                                                  (farAddress >>  8) & 0xFF,
                                                  (farAddress      ) & 0xFF,
                                                  farPort);
}

/*
 * Handle an incoming packet
 */
static void
epicsHandler(ospreyUDPendpoint endpoint, uint32_t farAddress, int farPort,
                                                    const char *buf, int length)
{
    int i, regCount;
    struct LEEPpacket const *cmdp = (struct LEEPpacket const *)buf;
    struct LEEPreg const *cmdReg = &cmdp->regs[0];
    static struct LEEPpacket reply;
    struct LEEPreg *replyReg = &reply.regs[0];
    int printed = 0;


    /*
     * Ignore packets that are clearly invalid
     */
    if ((length < LEEP_REG_TO_BYTES(1))
     || (length > LEEP_REG_TO_BYTES(LEEP_REG_CAPACITY))
     || (length != LEEP_REG_TO_BYTES((regCount = LEEP_BYTES_TO_REG(length))))) {
        if (debugFlags & (DEBUGFLAG_EPICS_READ | DEBUGFLAG_EPICS_WRITE)) {
            showClient(length, farAddress, farPort);
            printf("\n");
        }
        return;
    }
    reply.header = cmdp->header;

    /*
     * Process each register in turn
     */
    for (i = 0 ; i < regCount ; i++, cmdReg++, replyReg++) {
        uint32_t bits_addr = ntohl(cmdReg->bits_addr);
        uint32_t r;
        replyReg->bits_addr = cmdReg->bits_addr;
        if (bits_addr & LEEP_BITS_READ) {
            r = readReg(bits_addr & LEEP_ADDRESS_MASK);
            replyReg->value = htonl(r);
            if ((debugFlags & DEBUGFLAG_EPICS_READ) && (printed < 2)) {
                if (printed++ == 0) showClient(length, farAddress, farPort);
                printf(" %d:%08Xr%08X", i, bits_addr, r);
            }
        }
        else {
            r = ntohl(cmdReg->value);
            if ((debugFlags & DEBUGFLAG_EPICS_WRITE) && (printed < 2)) {
                if (printed++ == 0) showClient(length, farAddress, farPort);
                printf(" %d:%08Xw%08X", i, bits_addr, r);
            }
            writeReg(bits_addr & LEEP_ADDRESS_MASK, r);
            replyReg->value = cmdReg->value;
        }
    }
    if (printed) printf("\n");

    /*
     * Send the reply
     */
    ospreyUDPsendto(endpoint, farAddress, farPort, (char *)&reply, length);
}

/*
 * Create server
 */
void
epicsInit(void)
{
    if (ospreyUDPregisterEndpoint(LEEP_UDP_PORT, epicsHandler) == NULL) {
        printf("Can't register EPICS I/O UDP endpoint!\n");
    }
}
