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
#include "evg.h"
#include "gpio.h"
#include "iicFPGA.h"
#include "ioSelect.h"
#include "localPPS.h"
#include "mgt.h"
#include "mgtClkSwitch.h"
#include "mmcMailbox.h"
#include "mps.h"
#include "ospreyRFIN.h"
#include "ospreyTRGOUT.h"
#include "ospreyEVR.h"
#include "si570.h"
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
#define REG_LOOP_COUNT                      11
#define REG_FIRMWARE_BUILD_DATE             20
#define REG_SOFTWARE_BUILD_DATE             21
#define REG_FPGA_REBOOT                     30
#define REG_SECONDS_SINCE_BOOT              40
#define REG_FMC1_SERIAL_NUMBER              50
#define REG_FMC2_SERIAL_NUMBER              51
#define REG_FMC1_PART_NUMBER                54
#define REG_FMC2_PART_NUMBER                55
#define REG_MGT_RESET                       56
#define REG_FPGA_MODE_EVG                   60
#define REG_MARBLE_RFIN_INPUTS              70
#define REG_MARBLE_RFIN_ADC_A               71
#define REG_MARBLE_RFIN_ADC_B               72
#define REG_MARBLE_PMOD_INPUTS              75
#define REG_MARBLE_MGT_REFCLK_SOURCE        80
#define REG_MARBLE_PLL_SET_Y1               86
#define REG_MARBLE_PLL_SET_Y3               87
#define REG_MARBLE_PPS_LOCAL_CSR            88
#define REG_IOSELECT                        89
#define F_REG_SI570_BASE                    90
#  define SI570_SIZE                4
#define F_REG_SYSMON_BASE                   100
#  define SYSMON_SIZE               256
#define F_REG_IICFPGA_BASE                  356
#define F_REG_TRGOUT_BASE                   400

#define F_REG_RFIN_BASE                     500
#  define RFIN_SIZE                 OSPREYRFIN_SIZE

// See: Required Registers
//   https://github.com/osprey-dcs/feed-core/blob/master/documentation/proto.rst
#define F_REG_HELLO_BASE                    0
#  define HELLO_SIZE                4
#define F_REG_JSON_ROM_BASE                 0x800
#  define JSON_ROM_SIZE             0x800
#define F_REG_JSON_ROM_ALTERNATE_BASE       0x4000
#  define JSON_ROM_ALTERNATE_SIZE   0x4000

#define F_REG_EVG_BASE                      1000000
#  define EVG_SIZE                  100000
#define F_REG_EVR_BASE                      1100000
#  define EVR_SIZE                  OSPREYEVR_FEED_LIMIT

#define F_REG_MPS_LOCAL_BASE                100000
#  define MPS_LOCAL_SIZE            1000
#define F_REG_MPS_MERGE_BASE                110000
#  define MPS_MERGE_SIZE            1000

static int powerUpFlag = 1;
static int mgtClkSwitch0 = -1; // spoil
static uint32_t loopCount;

void
setMgtClkSwitch0(int inputClkIndex)
{
    if ((inputClkIndex < 0)
     || (inputClkIndex > MGT_CLK_SWITCH_INPUT_DISABLE_OUTPUT)) {
        return;
    }
    if (((inputClkIndex == MGT_CLK_SWITCH_INPUT_FMC1_GBTCLK0)
      || (inputClkIndex == MGT_CLK_SWITCH_INPUT_FMC1_GBTCLK1))
     && (!(ioSelectStatus() & IOSELECT_STATUS_FMC1_IS_PRESENT))) {
        printf("WARNING -- Setting MGT clock to FMC1 GBTCLK but "
               "RF-IN mezzanine card is not present!\n");
    }
    if (inputClkIndex != mgtClkSwitch0) {
        // The MGTs do not react well to having the reference frequency change,
        // and get stuck in an inoperative state with no status indicating an issue.
        // So briefly disable the reference to trigger PLL loss of lock.
        mgtClkSwitchConnectOutputToInput(MGT_CLK_SWITCH_OUTPUT_MGTCLK0,
                                         MGT_CLK_SWITCH_INPUT_DISABLE_OUTPUT);
        microsecondSpin(10);
        mgtClkSwitchConnectOutputToInput(MGT_CLK_SWITCH_OUTPUT_MGTCLK0,
                                         inputClkIndex);
        if (debugFlags & DEBUGFLAG_EPICS_WRITE) {
            printf("Drive MGT clock from ");
            switch(inputClkIndex) {
            case MGT_CLK_SWITCH_INPUT_FPGA_REF_CLK0:
                                                printf("FPGA Ref Clk 0"); break;
            case MGT_CLK_SWITCH_INPUT_SI570_CLK:
                                                printf("Marble SI570");   break;
            case MGT_CLK_SWITCH_INPUT_FMC1_GBTCLK0:
                                                printf("FMC1 GBTCLK0");   break;
            case MGT_CLK_SWITCH_INPUT_FMC1_GBTCLK1:
                                                printf("FMC1 GBTCLK1");   break;
            default:                   printf("Input %d", inputClkIndex); break;
            }
            printf(".\n");
        }
        mgtClkSwitch0 = inputClkIndex;
    }
}

#define RRANGE(REG) (F_REG_ ## REG ## _BASE) ... (F_REG_ ## REG ## _BASE + REG ## _SIZE - 1): \
    idx = offset - F_REG_ ## REG ## _BASE;

static void
writeReg(int offset, uint32_t value)
{
    uint32_t idx;
    switch(offset) {
    case REG_POWERUP_STATE:     if (value == 0)   powerUpFlag = 0;       return;
    case REG_FPGA_REBOOT:       if (value == 100) resetFPGA(0);          return;
    case REG_FPGA_MODE_EVG:             ioSelectActivateEVG(value != 0); return;
    case REG_MARBLE_MGT_REFCLK_SOURCE:  setMgtClkSwitch0(value);         return;
    case REG_MARBLE_PLL_SET_Y1:         clockAdjustSetDAC(0, value);     return;
    case REG_MARBLE_PLL_SET_Y3:         clockAdjustSetDAC(1, value);     return;
    case REG_MARBLE_PPS_LOCAL_CSR:      localPPSenable(value);           return;
    case REG_MGT_RESET:       if(value) mgtReset();                      return;
    case RRANGE(SI570) {
        if((mgtClkSwitch0==MGT_CLK_SWITCH_INPUT_SI570_CLK)
            && (idx==1) )
        {
            // The MGTs do not react well to having the reference frequency change,
            // and get stuck in an inoperative state with no status indicating an issue.
            // So disable the reference to trigger PLL loss of lock.
            mgtClkSwitchConnectOutputToInput(MGT_CLK_SWITCH_OUTPUT_MGTCLK0,
                                             MGT_CLK_SWITCH_INPUT_DISABLE_OUTPUT);
        }
        si570Write(idx, value);
        if((mgtClkSwitch0==MGT_CLK_SWITCH_INPUT_SI570_CLK)
            && (idx==1) )
        {
            mgtClkSwitchConnectOutputToInput(MGT_CLK_SWITCH_OUTPUT_MGTCLK0,
                                             mgtClkSwitch0);
        }
        return;
    }
    case RRANGE(MPS_LOCAL) {
        mpsWrite(idx, value);
    }
    case RRANGE(RFIN) {
        osreyRFINWrite(idx, value);
    }
    // external IP cores
    case RRANGE(EVG) {
        ospreyEVG_FEEDwrite(idx, value);
    }
    case RRANGE(EVR) {
        ospreyEVR_FEEDwrite(idx, value);
    }
    }
}

static uint32_t
readReg(int offset)
{
    uint32_t idx;
    switch(offset) {
    case REG_POWERUP_STATE:       return powerUpFlag;
    case REG_LOOP_COUNT:          return loopCount;
    case REG_FIRMWARE_BUILD_DATE: return GPIO_READ(GPIO_IDX_FIRMWARE_DATE);
    case REG_SOFTWARE_BUILD_DATE: return SOFTWARE_BUILD_DATE;
    case REG_SECONDS_SINCE_BOOT:  return GPIO_READ(GPIO_IDX_SECONDS_SINCE_BOOT);
    case REG_FMC1_SERIAL_NUMBER:  return iicFPGAgetSerialNumber(0);
    case REG_FMC2_SERIAL_NUMBER:  return iicFPGAgetSerialNumber(1);
    case REG_FMC1_PART_NUMBER:    return iicFPGAgetPartNumber(0);
    case REG_FMC2_PART_NUMBER:    return iicFPGAgetPartNumber(1);
    case REG_MGT_RESET:           return 0;
    case REG_FPGA_MODE_EVG:       return (ioSelectStatus()&IOSELECT_STATUS_IS_EVG)!=0;
    case REG_MARBLE_RFIN_ADC_A:   return ospreyRFINreadADS7253(0);
    case REG_MARBLE_RFIN_ADC_B:   return ospreyRFINreadADS7253(1);
    case REG_MARBLE_RFIN_INPUTS:  return GPIO_READ(GPIO_IDX_PMOD_FMC_MONITOR)
                                                                       & 0xFFFF;
    case REG_MARBLE_PMOD_INPUTS:  return GPIO_READ(GPIO_IDX_PMOD_FMC_MONITOR)
                                                                          >> 16;
    case RRANGE(SI570) {
        return si570Read(idx);
    }
    case REG_IOSELECT:            return ioSelectStatus();
    case RRANGE(SYSMON) {
        unsigned bank = idx & 0xE0;
        unsigned index = idx & 0x1F;
        switch (bank) {
        case 0x00:  return xadcFetchSysmon(index);
        case 0x20:  return mmcMailboxFetchSysmon(index);
        case 0xA0:  return evgFetchSysmon(index);
        case 0xC0:  return clockAdjustFetchSysmon(index);
        case 0xE0:  return mgtFetchSysmon(index);
        }
        return 0xdeadbeef;
    }
    case RRANGE(IICFPGA) {
        return iicFPGAfetchSysmon(idx);
    }
    case REG_MARBLE_MGT_REFCLK_SOURCE: return mgtClkSwitch0;
    case REG_MARBLE_PPS_LOCAL_CSR:     return localPPSstatus();
    case RRANGE(MPS_LOCAL) {
        return mpsRead(idx);
    }
    case RRANGE(RFIN) {
        return osreyRFINRead(idx);
    }
    case RRANGE(TRGOUT) {
        return osreyTRGOUTRead(idx);
    }
    // external IP cores
    case RRANGE(EVG) {
        return ospreyEVG_FEEDread(idx);
    }
    case RRANGE(EVR) {
        return ospreyEVR_FEEDread(idx);
    }
    // Generic LEEP registers
    case RRANGE(HELLO) {
        static const
        union LEEPbaseRegs { char u_c[16]; uint32_t u_l[4]; }
        baseRegs = {.u_c = "Hello World!\r\n\r\n"};
        return ntohl(baseRegs.u_l[idx]);
    }
    case RRANGE(JSON_ROM) {
        return 0; // indicate use of alternate/larger ROM
    }
    case RRANGE(JSON_ROM_ALTERNATE) {
#   include "JSONrom.h"
STATIC_ASSERT(NELEM(config_romx) < JSON_ROM_ALTERNATE_SIZE);
        if(idx < NELEM(config_romx))
            return config_romx[idx];
        return 0;
    }
    }
    return 0x2bad4700;
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

void epicsCrank()
{
    loopCount++;
}
