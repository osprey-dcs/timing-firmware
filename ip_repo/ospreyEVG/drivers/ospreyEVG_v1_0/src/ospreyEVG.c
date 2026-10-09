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
 * Basic MRF-compatible event generator
 * Assume only one per processor
 */
#include <xil_io.h>
#include "xil_printf.h"

#include "ospreyEVG.h"

#define printf xil_printf

#define REG_CSR                (0*4)
#define REG_CONFIG             (1*4)
#define REG_CLK_RATE           (2*4)
#define REG_SECONDS            (3*4)
#define REG_HEARTBEAT_DIVISOR  (4*4)
#define REG_HW_TRIGGER_CONFIG  (5*4)
#define REG_SW_EVENT           (6*4)
#define REG_SEQ_ADDR_CODE      (7*4)
#define REG_SEQ_GAP            (8*4)
#define REG_SEQ_COUNT          (9*4)
#define REG_DBUS_MAP           (10*4)
#define REG_TIMER_CSR          (11*4)
#define REG_LATENCY_STATUS     (12*4)
#define REG_HW_TRIGGER_COUNT   (13*4)
#define REG_TIMER_CONFIG_BASE  (16*4)

// REG_CSR
// Read for:
//  0xFF000000 - Bank normal trigger mode
//  0x00F00000 - Running Seq. bank.  1-indexed.  0 == not running
//  0x000FF000 - Seq. bank triggered mask
//  0x00000FF0 - Seq. bank armed mask
//  0x00000004 - PPS toggle
//  0x00000002 - Seconds valid
//  0x00000001 - PPS valid
//
// Write with some CSR_CMD_* : 0xF0000000
//  Arm/Disarm
//  0x1000____
//        FF   - disarm bank mask
//          FF - arm bank mask
#define CSR_CMD_ARM   0x10000000
//  0x20_000__
//      E      - Bank index (0-7)
//          FF - Timer mask
#define CSR_CMD_TIMER 0x20000000
//  0x30_0____
//      E      - Bank index (0-7)
//      1      - edge (0 - rise, 1 - fall)
//        FFFF - Input mask
#define CSR_CMD_HWTRG 0x30000000
//  0x400000__
//          FF - Bank mask
#define CSR_CMD_SWTRG 0x40000000
// 0x50000000
#define CSR_CMD_CANCL 0x50000000
// 0x6000____
//       FF   - Bank mask, select single trigger mode
//         FF - Bank mask, select normal trigger mode
#define CSR_CMD_NORML 0x60000000

// REG_TIMER_CSR
#define TIMER_CMD_NOP    0
#define TIMER_CMD_STOP   1
#define TIMER_CMD_RESUME 2
#define TIMER_CMD_START  3

// REG_SEQ_ADDR_CODE
#define SEQ_ADDR_CODE_W_WRITE_ENABLE        0x80000000

#define INPUTS_CAPACITY 16
#define TIMER_CAPACITY  8
struct timerConfig {
    int     code;
    int32_t divisor;
};
struct evgInfo {
    uint32_t            baseAddr;
    evgConfigInfo conf;
    struct timerConfig  timers[TIMER_CAPACITY];
};
static struct evgInfo evgInfo;

int
ospreyEVGInit(uint32_t baseAddress)
{
    int a, memCapacity;
    if (!baseAddress) return -1;
    evgInfo.baseAddr = baseAddress;
    uint32_t config = Xil_In32(evgInfo.baseAddr + REG_CONFIG);
    if((config&0xf0000000) != 0xa0000000) {
        printf("ERROR %s(%08x) not core\n", __func__, (unsigned)baseAddress);
        return -1;
    }
    evgConfigInfo *conf = &evgInfo.conf;
    conf->hwTriggerCount = (config & OSPREY_EVG_CONFIG_HW_TRIG_COUNT_MASK) >>
                                          OSPREY_EVG_CONFIG_HW_TRIG_COUNT_SHIFT;
    conf->timerCount = (config & OSPREY_EVG_CONFIG_TIMER_COUNT_MASK) >>
                                            OSPREY_EVG_CONFIG_TIMER_COUNT_SHIFT;
    conf->bankCount = (config & OSPREY_EVG_CONFIG_BANK_COUNT_MASK) >>
                                             OSPREY_EVG_CONFIG_BANK_COUNT_SHIFT;
    conf->seqAddrWidth = (config & OSPREY_EVG_CONFIG_SEQ_ADDR_WIDTH_MASK) >>
                                         OSPREY_EVG_CONFIG_SEQ_ADDR_WIDTH_SHIFT;
    conf->rxCount = (config & OSPREY_EVG_CONFIG_RX_COUNT_MASK) >>
                                               OSPREY_EVG_CONFIG_RX_COUNT_SHIFT;
    if (conf->timerCount > TIMER_CAPACITY) {
        conf->timerCount = TIMER_CAPACITY;
    }
    /*
     * Fill with 'end-of-sequence' codes for the benefit
     * of clients that write unterminated sequences.
     */
    memCapacity = (1 << conf->seqAddrWidth) * conf->bankCount;
    for (a = 0 ; a < memCapacity ; a++) {
        Xil_Out32(evgInfo.baseAddr + REG_SEQ_ADDR_CODE,
                                 SEQ_ADDR_CODE_W_WRITE_ENABLE | (a << 8) | 255);
        Xil_Out32(evgInfo.baseAddr + REG_SEQ_GAP, 0);
    }

    // disable DBus mapping
    for (a = 0 ; a < 8 ; a++) {
        ospreyEVGSetDbusInputMap(a, 0);
    }

    printf("%s(%08x): #Rx:%u #Trg:%u, #Tmr:%u #Bank:%u sAddrW:%u\n", __func__, (unsigned)baseAddress,
           conf->rxCount, conf->hwTriggerCount, conf->timerCount, conf->bankCount,
           conf->seqAddrWidth);
    return 0;
}

int
ospreyEVGStatus(void)
{
    if (!evgInfo.baseAddr) return -1;
    return Xil_In32(evgInfo.baseAddr + REG_CSR);
}

const evgConfigInfo* ospreyEVGGetConf(void)
{
    return &evgInfo.conf;
}

int
ospreyEVGGetPPStoggle(void)
{
    return ospreyEVGStatus() & OSPREY_EVG_STATUS_PPS_TOGGLE;
}

int
ospreyEVGSetSeconds(uint32_t posixSeconds)
{
    if (!evgInfo.baseAddr) return -1;
    Xil_Out32(evgInfo.baseAddr + REG_SECONDS, posixSeconds);
    return 0;
}

int
ospreyEVGSetHeartbeatDivisor(uint32_t divisor)
{
    if (!evgInfo.baseAddr) return -1;
    Xil_Out32(evgInfo.baseAddr + REG_HEARTBEAT_DIVISOR, divisor);
    return 0;
}

int
ospreyEVGSetTimerControl(uint32_t control)
{
    int i;
    if (!evgInfo.baseAddr) return -1;
    for (i = 0 ; i <  evgInfo.conf.timerCount ; i++) {
        int cmd = (control >> (2*i)) & 0x3;
        /*
         * Reject attempts to (re)start unreasonably-configured timers
         */
        if ((cmd == TIMER_CMD_RESUME) || (cmd == TIMER_CMD_START)) {
            if ((evgInfo.timers[i].code == 0)
             || (evgInfo.timers[i].divisor < 40)) {
                control &= ~(0x3 << (2*i));
            }
        }
    }
    Xil_Out32(evgInfo.baseAddr + REG_TIMER_CSR, control);
    return 0;
}

int
ospreyEVGGetTimerStatus(void)
{
    if (!evgInfo.baseAddr) return -1;
    return Xil_In32(evgInfo.baseAddr + REG_TIMER_CSR);
}

int
ospreyEVGSetTimerEvent(int timerIndex, int evCode)
{
    if (!evgInfo.baseAddr) return -1;
    if ((evCode <= 0) || (evCode > 255)) return -2;
    if ((timerIndex < 0) || (timerIndex >= evgInfo.conf.timerCount)) return -3;
    evgInfo.timers[timerIndex].code = evCode;
    Xil_Out32(evgInfo.baseAddr + REG_TIMER_CONFIG_BASE +
                                                   (timerIndex<<3) + 0, evCode);
    return 0;
}

static
int ospreyEVGGetTimerEvent(int timerIndex)
{
    if (!evgInfo.baseAddr) return -1;
    if ((timerIndex < 0) || (timerIndex >= evgInfo.conf.timerCount)) return -3;
    return Xil_In32(evgInfo.baseAddr + REG_TIMER_CONFIG_BASE + (timerIndex<<3) + 0);
}

int
ospreyEVGSetTimerDivisor(int timerIndex, uint32_t divisor)
{
    if (!evgInfo.baseAddr) return -1;
    if (divisor <= 40) return -2;
    if ((timerIndex < 0) || (timerIndex >= evgInfo.conf.timerCount)) return -3;
    evgInfo.timers[timerIndex].divisor = divisor;
    // divisor-2 accounts of over-count due to use of underflow as reset condition.
    Xil_Out32(evgInfo.baseAddr + REG_TIMER_CONFIG_BASE +
                                              (timerIndex<<3) + 4, divisor - 2);
    return 0;
}

static
int
ospreyEVGGetTimerDivisor(int timerIndex, uint32_t *divisor)
{
    if (!evgInfo.baseAddr) return -1;
    if (!divisor) return -2;
    if ((timerIndex < 0) || (timerIndex >= evgInfo.conf.timerCount)) return -3;
    *divisor = Xil_In32(evgInfo.baseAddr + REG_TIMER_CONFIG_BASE + (timerIndex<<3) + 4);
    return 0;
}

int
ospreyEVGSetHwTriggerEvent(int hwTriggerIndex, int edge, int evCode)
{
    if (!evgInfo.baseAddr) return -1;
    if ((hwTriggerIndex < 0) || (hwTriggerIndex >= evgInfo.conf.hwTriggerCount)
     || (edge < 0) || (edge > 1)
     || (evCode < 0) || (evCode > 255)) return -2;
    hwTriggerIndex = (hwTriggerIndex << 1) | edge;
    Xil_Out32(evgInfo.baseAddr + REG_HW_TRIGGER_CONFIG,
                                                (hwTriggerIndex << 8) | evCode);
    return 0;
}

int
ospreyEVGSendSoftwareEvent(int evCode)
{
    if (!evgInfo.baseAddr) return -1;
    if ((evCode <= 0) || (evCode > 255)) return -2;
    Xil_Out32(evgInfo.baseAddr + REG_SW_EVENT, evCode);
    return 0;
}

int
ospreyEVGSequencerArm(int banks)
{
    if (!evgInfo.baseAddr) return -1;
    if (banks < 0) return -2;
    banks &= 0xFF;
    Xil_Out32(evgInfo.baseAddr + REG_CSR, CSR_CMD_ARM | banks);
    return 0;
}

int
ospreyEVGSequencerDisarm(int banks)
{
    if (!evgInfo.baseAddr) return -1;
    if (banks < 0) return -2;
    banks &= 0xFF;
    Xil_Out32(evgInfo.baseAddr + REG_CSR, CSR_CMD_ARM | banks << 8);
    return 0;
}

int
ospreyEVGSequencerSoftTrigger(int banks)
{
    if (!evgInfo.baseAddr) return -1;
    if (banks < 0) return -2;
    banks &= 0xFF;
    Xil_Out32(evgInfo.baseAddr + REG_CSR, CSR_CMD_SWTRG | banks);
    return 0;
}

int
ospreyEVGSequencerCancel(void)
{
    if (!evgInfo.baseAddr) return -1;
    Xil_Out32(evgInfo.baseAddr + REG_CSR, CSR_CMD_CANCL);
    return 0;
}

static
int ospreyEVGSequencerTrigMode(uint32_t modeMask)
{
    if (!evgInfo.baseAddr) return -1;
    if (modeMask & ~0xffff) return -2;
    Xil_Out32(evgInfo.baseAddr + REG_CSR, CSR_CMD_NORML | modeMask);
    return 0;
}

int
ospreyEVGSequencerSetHwTrigger(int bank, int edge, int hwTriggerBitmap)
{
    if (!evgInfo.baseAddr) return -1;
    if ((bank < 0) || (bank >= evgInfo.conf.bankCount)
     || (hwTriggerBitmap < 0)
     || (hwTriggerBitmap >= (1 << evgInfo.conf.hwTriggerCount))
     || (edge < 0) || (edge > 1)) return -2;
    Xil_Out32(evgInfo.baseAddr + REG_CSR, CSR_CMD_HWTRG |
                                          (bank << 21) |
                                          (edge << 20) |
                                          hwTriggerBitmap);
    return 0;
}

int ospreyEVGSequencerSetTimerTrigger(int bank, int timerBitmap)
{
    if (!evgInfo.baseAddr) return -1;
    if ((bank < 0) || (bank >= evgInfo.conf.bankCount)
        || (timerBitmap < 0)
        || (timerBitmap >= (1 << evgInfo.conf.timerCount)))
        return -2;

    Xil_Out32(evgInfo.baseAddr + REG_CSR, CSR_CMD_TIMER |
                                              (bank << 21) |
                                              timerBitmap);

    return 0;
}

int
ospreyEVGSequencerWriteCode(int bank, int address, int evCode)
{
    if (!evgInfo.baseAddr) return -1;
    if ((bank < 0) || (bank >= evgInfo.conf.bankCount)
     || (address < 0) || (address >= (1 << evgInfo.conf.seqAddrWidth))
     || (evCode < 0) || (evCode > 255)) return -2;
    Xil_Out32(evgInfo.baseAddr + REG_SEQ_ADDR_CODE,
                             SEQ_ADDR_CODE_W_WRITE_ENABLE | 
                             (((bank << evgInfo.conf.seqAddrWidth) | address) << 8) |
                             evCode);
    return 0;
}

int
ospreyEVGSequencerWriteDelay(int bank, int address, uint32_t delay)
{
    if (!evgInfo.baseAddr) return -1;
    if ((bank < 0) || (bank >= evgInfo.conf.bankCount)
     || (address < 0) || (address >= (1 << evgInfo.conf.seqAddrWidth))) return -2;
    Xil_Out32(evgInfo.baseAddr + REG_SEQ_ADDR_CODE,
                             (((bank << evgInfo.conf.seqAddrWidth) | address) << 8));
    Xil_Out32(evgInfo.baseAddr + REG_SEQ_GAP, delay);
    return 0;
}

int
ospreyEVGSequencerReadback(int bank, int address, uint32_t *delay)
{
    if (!evgInfo.baseAddr) return -1;
    if ((bank < 0) || (bank >= evgInfo.conf.bankCount)
     || (address < 0) || (address >= (1 << evgInfo.conf.seqAddrWidth))) return -2;
    Xil_Out32(evgInfo.baseAddr + REG_SEQ_ADDR_CODE,
                             (((bank << evgInfo.conf.seqAddrWidth) | address) << 8));
    if (delay) {
        *delay = Xil_In32(evgInfo.baseAddr + REG_SEQ_GAP);
    }
    return Xil_In32(evgInfo.baseAddr + REG_SEQ_ADDR_CODE) & 0xFF;
}

int
ospreyEVGLatencyReadback(int rxIndex)
{
    uint32_t latency, oldLatency = ~0;

    if (!evgInfo.baseAddr) return -1;
    if ((rxIndex < 0) || (rxIndex >= evgInfo.conf.rxCount)) return -2;
    Xil_Out32(evgInfo.baseAddr + REG_LATENCY_STATUS, rxIndex);
    for (;;) {
        latency = Xil_In32(evgInfo.baseAddr + REG_LATENCY_STATUS);
        if (latency == oldLatency) {
            if ((int)(latency & 0xFF) != rxIndex) return -3;
            return (latency >> 8);
        }
        oldLatency = latency;
    }
}

int
ospreyEVGSetDbusInputMap(uint8_t bit, uint32_t inputSel)
{
    if (!evgInfo.baseAddr) return -1;
    if (bit >= 8 || (inputSel > evgInfo.conf.hwTriggerCount)) return -1;
    Xil_Out32(evgInfo.baseAddr + REG_DBUS_MAP, 0x80000000 | (((uint32_t)bit)<<24u) | inputSel);
    return 0;
}

uint32_t ospreyEVGGetDbusInputMap(uint8_t bit)
{
    if (!evgInfo.baseAddr) return -1;
    if (bit>=8) return -1;
    Xil_Out32(evgInfo.baseAddr + REG_DBUS_MAP, ((uint32_t)bit)<<24u);
    return Xil_In32(evgInfo.baseAddr + REG_DBUS_MAP) & 0x00ffffff;
}

#define SEQ_MAX_CAPACITY                 4096
#define SEQ_MAX_BANKS                    8

/*
 * FEED I/O support
 */
#define F_REG_STATUS                      0
// former F_REG_CONFIG
#define F_REG_HEARTBEAT_DIVISOR           2
#define F_REG_SOFTWARE_EVENT              3
#define F_REG_SEQ_ARM                     4
#define F_REG_SEQ_DISARM                  5
#define F_REG_SEQ_TRIGGER                 6
#define F_REG_SEQ_CANCEL                  7
#define F_REG_SEQ_TRIG_MODE               8
// former F_REG_DBUS_INPUT_MAP
#define F_REG_TIMER_CSR                   10
#define F_REG_SET_SECONDS                 11
#define F_REG_INPUT_COUNT                 12
#define F_REG_TIMER_COUNT                 13
#define F_REG_SEQ_BANK_COUNT              14
#define F_REG_SEQ_ADDR_WIDTH              15
#define F_REG_RX_COUNT                    16
#define F_REG_DBUS_TO_INPUT_SELECT_BASE   17
#  define DBUS_TO_INPUT_SELECT_SIZE  8
#define F_REG_HW_TRIGGER_COUNT_BASE       25
#  define HW_TRIGGER_COUNT_SIZE           INPUTS_CAPACITY
#define F_REG_SEQ_BANK_TRIG_COUNT_BASE    50
#  define SEQ_BANK_TRIG_COUNT_SIZE        SEQ_MAX_BANKS
#define F_REG_TIMER_EVENT_BASE            100
#  define TIMER_EVENT_SIZE                TIMER_CAPACITY
#define F_REG_TIMER_DIVISOR_BASE          120
#  define TIMER_DIVISOR_SIZE              TIMER_CAPACITY
#define F_REG_HWTRIGGER_EVENT_BASE        140
#  define HWTRIGGER_EVENT_SIZE            INPUTS_CAPACITY
#define F_REG_SEQ_HWTRIGGER_CONFIG_BASE   180
#  define SEQ_HWTRIGGER_CONFIG_SIZE       INPUTS_CAPACITY
#define F_REG_LATENCY_READBACK_BASE       200
#  define LATENCY_READBACK_SIZE           8
#define F_REG_SEQ_TIMERTRIGGER_CONFIG_BASE 220
#  define SEQ_TIMERTRIGGER_CONFIG_SIZE    SEQ_MAX_BANKS
#define F_REG_SEQ_PATTERN_BASE            8192
#  define SEQ_PATTERN_SIZE                (SEQ_MAX_BANKS*SEQ_MAX_CAPACITY*2)

#define RRANGE(REG) (F_REG_ ## REG ## _BASE) ... (F_REG_ ## REG ## _BASE + REG ## _SIZE - 1): \
    idx = offset - F_REG_ ## REG ## _BASE;

int
ospreyEVG_FEEDwrite(int offset, uint32_t value)
{
    int idx;
    if (!evgInfo.baseAddr) return -1;
    switch(offset) {
    case F_REG_SET_SECONDS:      ospreyEVGSetSeconds(value);           return 0;
    case F_REG_HEARTBEAT_DIVISOR:ospreyEVGSetHeartbeatDivisor(value);  return 0;
    case F_REG_SOFTWARE_EVENT:   ospreyEVGSendSoftwareEvent(value);    return 0;
    case F_REG_SEQ_ARM:          ospreyEVGSequencerArm(value);         return 0;
    case F_REG_SEQ_DISARM:       ospreyEVGSequencerDisarm(value);      return 0;
    case F_REG_SEQ_TRIGGER:      ospreyEVGSequencerSoftTrigger(value); return 0;
    case F_REG_SEQ_CANCEL:       ospreyEVGSequencerCancel();           return 0;
    case F_REG_SEQ_TRIG_MODE:    ospreyEVGSequencerTrigMode(value);    return 0;
    case F_REG_TIMER_CSR:        ospreyEVGSetTimerControl(value);      return 0;
    case RRANGE(DBUS_TO_INPUT_SELECT) {
        ospreyEVGSetDbusInputMap(idx, value);
        return 0;
    }
    case RRANGE(HWTRIGGER_EVENT) {
        int hwTriggerIndex = idx >> 1;
        int edge = idx & 0x1;
        ospreyEVGSetHwTriggerEvent(hwTriggerIndex, edge, value);
        return 0;
    }
    case RRANGE(TIMER_EVENT) {
        ospreyEVGSetTimerEvent(idx, value);
        return 0;
    }
    case RRANGE(TIMER_DIVISOR) {
        ospreyEVGSetTimerDivisor(idx, value);
        return 0;
    }
    case RRANGE(SEQ_HWTRIGGER_CONFIG) {
        int bank = idx >> 1;
        int edge = idx & 0x1;
        ospreyEVGSequencerSetHwTrigger(bank, edge, value);
        return 0;
    }
    case RRANGE(SEQ_TIMERTRIGGER_CONFIG) {
        int bank = idx;
        ospreyEVGSequencerSetTimerTrigger(bank, value);
        return 0;
    }
    case RRANGE(SEQ_PATTERN) {
        int isCode = idx & 0x1;
        int address = (idx >> 1) % SEQ_MAX_CAPACITY;
        int bank = (idx >> 1) / SEQ_MAX_CAPACITY;
        if (isCode) {
            return ospreyEVGSequencerWriteCode(bank, address, value);
        }
        else {
            return ospreyEVGSequencerWriteDelay(bank, address, value);
        }
    }
    }
    return -1;
}

uint32_t
ospreyEVG_FEEDread(int offset)
{
    int idx;
    if (!evgInfo.baseAddr) return -1;
    switch(offset) {
    case F_REG_STATUS:               return ospreyEVGStatus();
    case F_REG_TIMER_CSR:            return ospreyEVGGetTimerStatus();
    case F_REG_INPUT_COUNT:          return ospreyEVGGetConf()->hwTriggerCount;
    case F_REG_TIMER_COUNT:          return ospreyEVGGetConf()->timerCount;
    case F_REG_SEQ_BANK_COUNT:       return ospreyEVGGetConf()->bankCount;
    case F_REG_SEQ_ADDR_WIDTH:       return ospreyEVGGetConf()->seqAddrWidth;
    case F_REG_RX_COUNT:             return ospreyEVGGetConf()->rxCount;
    case F_REG_SEQ_TRIG_MODE:        return ospreyEVGStatus()>>24u;
    case RRANGE(DBUS_TO_INPUT_SELECT) {
        return ospreyEVGGetDbusInputMap(idx);
    }
    case RRANGE(LATENCY_READBACK) {
        return ospreyEVGLatencyReadback(idx);
    }
    case RRANGE(TIMER_EVENT) {
        return ospreyEVGGetTimerEvent(idx);
    }
    case RRANGE(TIMER_DIVISOR) {
        uint32_t value = 0x1badface;
        ospreyEVGGetTimerDivisor(idx, &value);
        return value;
    }
    case RRANGE(HW_TRIGGER_COUNT) {
        Xil_Out32(evgInfo.baseAddr + REG_HW_TRIGGER_COUNT, idx<<8u);
        return Xil_In32(evgInfo.baseAddr + REG_HW_TRIGGER_COUNT) & 0xff;
    }
    case RRANGE(SEQ_BANK_TRIG_COUNT) {
        return (Xil_In32(evgInfo.baseAddr + REG_SEQ_COUNT) >> (idx*4)) & 0xff;
    }
    case RRANGE(SEQ_PATTERN) {
        int isCode = idx & 0x1;
        int address = (idx >> 1) % SEQ_MAX_CAPACITY;
        int bank = (idx >> 1) / SEQ_MAX_CAPACITY;
        static uint32_t nextCode;
        if (!isCode) {
            uint32_t delay;
            nextCode = ospreyEVGSequencerReadback(bank, address, &delay);
            return delay;
        } else {
            // assume sequential readback
            return nextCode;
        }
    }
    }
    return 0xdeadbeef ^ offset;
}
