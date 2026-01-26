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
#include <stdio.h>
#include <xil_io.h>
#include <xparameters.h>
#include "ospreyEVG.h"

#define REG_CSR                (0*4)
#define REG_CONFIG             (1*4)
#define REG_CLK_RATE           (2*4)
#define REG_SECONDS            (3*4)
#define REG_HEARTBEAT_DIVISOR  (4*4)
#define REG_HW_TRIGGER_CONFIG  (5*4)
#define REG_SW_EVENT           (6*4)
#define REG_SEQ_ADDR_CODE      (7*4)
#define REG_SEQ_GAP            (8*4)
#define REG_HW_TRIGGER_MAP     (9*4)
#define REG_DBUS_MAP           (10*4)
#define REG_LATENCY_STATUS     (12*4)
#define REG_TIMER_CONFIG_BASE  (16*4)

#define CSR_W_CANCEL                    0x80000000
#define CSR_W_APPLY_SOFT_TRIGGER        0x40000000
#define CSR_W_CONFIGURE_HARD_TRIGGER    0x20000000

#define SEQ_ADDR_CODE_W_WRITE_ENABLE        0x80000000

struct evgInfo {
    uint32_t baseAddr;
    char     hwTriggerCount;
    char     timerCount;
    char     bankCount;
    char     seqAddrWidth;
    char     rxCount;
};
static struct evgInfo evgInfo;

int
ospreyEVGInit(uint32_t baseAddress)
{
    uint32_t config;
    int a, memCapacity;
    if (!baseAddress) return -1;
    evgInfo.baseAddr = baseAddress;
    config = ospreyEVGConfiguration();
    evgInfo.hwTriggerCount = (config & OSPREY_EVG_CONFIG_HW_TRIG_COUNT_MASK) >>
                                          OSPREY_EVG_CONFIG_HW_TRIG_COUNT_SHIFT;
    evgInfo.timerCount = (config & OSPREY_EVG_CONFIG_TIMER_COUNT_MASK) >>
                                            OSPREY_EVG_CONFIG_TIMER_COUNT_SHIFT;
    evgInfo.bankCount = (config & OSPREY_EVG_CONFIG_BANK_COUNT_MASK) >>
                                             OSPREY_EVG_CONFIG_BANK_COUNT_SHIFT;
    evgInfo.seqAddrWidth = (config & OSPREY_EVG_CONFIG_SEQ_ADDR_WIDTH_MASK) >>
                                         OSPREY_EVG_CONFIG_SEQ_ADDR_WIDTH_SHIFT;
    evgInfo.rxCount = (config & OSPREY_EVG_CONFIG_RX_COUNT_MASK) >>
                                               OSPREY_EVG_CONFIG_RX_COUNT_SHIFT;
    /*
     * Fill with 'end-of-sequence' codes for the benefit
     * of clients that write unterminated sequences.
     */
    memCapacity = (1 << evgInfo.seqAddrWidth) * evgInfo.bankCount;
    for (a = 0 ; a < memCapacity ; a++) {
        Xil_Out32(evgInfo.baseAddr + REG_SEQ_ADDR_CODE,
                                 SEQ_ADDR_CODE_W_WRITE_ENABLE | (a << 8) | 255);
        Xil_Out32(evgInfo.baseAddr + REG_SEQ_GAP, 0);
    }

    /*
     * Set default input mapping.   FIXME -- maybe not for dbus????
     */
    ospreyEVGSetHwTriggerInputMap(0x87654321);
    ospreyEVGSetDbusInputMap(0xFEDCBA98);
    return 0;
}

int
ospreyEVGStatus(void)
{
    if (!evgInfo.baseAddr) return -1;
    return Xil_In32(evgInfo.baseAddr + REG_CSR);
}

int
ospreyEVGConfiguration(void)
{
    if (!evgInfo.baseAddr) return -1;
    return Xil_In32(evgInfo.baseAddr + REG_CONFIG);
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
ospreyEVGSetTimerEvent(int timerIndex, int evCode)
{
    if (!evgInfo.baseAddr) return -1;
    if ((evCode <= 0) || (evCode > 255)) return -2;
    if ((timerIndex < 0) || (timerIndex >= evgInfo.timerCount)) return -3;
    Xil_Out32(evgInfo.baseAddr + REG_TIMER_CONFIG_BASE +
                                                   (timerIndex<<3) + 0, evCode);
    return 0;
}

int
ospreyEVGSetTimerDivisor(int timerIndex, uint32_t divisor)
{
    if (!evgInfo.baseAddr) return -1;
    if ((timerIndex < 0) || (timerIndex >= evgInfo.timerCount)) return -3;
    if (divisor <= 1) divisor = ~(uint32_t)0;
    Xil_Out32(evgInfo.baseAddr + REG_TIMER_CONFIG_BASE +
                                              (timerIndex<<3) + 4, divisor - 2);
    return 0;
}

int
ospreyEVGSetHwTriggerEvent(int hwTriggerIndex, int edge, int evCode)
{
    if (!evgInfo.baseAddr) return -1;
    if ((hwTriggerIndex < 0) || (hwTriggerIndex >= evgInfo.hwTriggerCount)
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
    Xil_Out32(evgInfo.baseAddr + REG_CSR, banks);
    return 0;
}

int
ospreyEVGSequencerDisarm(int banks)
{
    if (!evgInfo.baseAddr) return -1;
    if (banks < 0) return -2;
    banks &= 0xFF;
    Xil_Out32(evgInfo.baseAddr + REG_CSR, banks << 8);
    return 0;
}

int
ospreyEVGSequencerSoftTrigger(int banks)
{
    if (!evgInfo.baseAddr) return -1;
    if (banks < 0) return -2;
    banks &= 0xFF;
    Xil_Out32(evgInfo.baseAddr + REG_CSR, CSR_W_APPLY_SOFT_TRIGGER | banks);
    return 0;
}

int
ospreyEVGSequencerCancel(void)
{
    if (!evgInfo.baseAddr) return -1;
    Xil_Out32(evgInfo.baseAddr + REG_CSR, CSR_W_CANCEL);
    return 0;
}

int
ospreyEVGSequencerSetHwTrigger(int bank, int edge, int hwTriggerBitmap)
{
    if (!evgInfo.baseAddr) return -1;
    if ((bank < 0) || (bank >= evgInfo.bankCount)
     || (hwTriggerBitmap < 0)
     || (hwTriggerBitmap >= (1 << evgInfo.hwTriggerCount))
     || (edge < 0) || (edge > 1)) return -2;
    Xil_Out32(evgInfo.baseAddr + REG_CSR, CSR_W_CONFIGURE_HARD_TRIGGER |
                                          (bank << 21) |
                                          (edge << 20) |
                                          hwTriggerBitmap);
    return 0;
}

int
ospreyEVGSequencerWriteCode(int bank, int address, int evCode)
{
    if (!evgInfo.baseAddr) return -1;
    if ((bank < 0) || (bank >= evgInfo.bankCount)
     || (address < 0) || (address >= (1 << evgInfo.seqAddrWidth))
     || (evCode < 0) || (evCode > 255)) return -2;
    Xil_Out32(evgInfo.baseAddr + REG_SEQ_ADDR_CODE,
                             SEQ_ADDR_CODE_W_WRITE_ENABLE | 
                             (((bank << evgInfo.seqAddrWidth) | address) << 8) |
                             evCode);
    return 0;
}

int
ospreyEVGSequencerWriteDelay(int bank, int address, uint32_t delay)
{
    if (!evgInfo.baseAddr) return -1;
    if ((bank < 0) || (bank >= evgInfo.bankCount)
     || (address < 0) || (address >= (1 << evgInfo.seqAddrWidth))) return -2;
    Xil_Out32(evgInfo.baseAddr + REG_SEQ_ADDR_CODE,
                             (((bank << evgInfo.seqAddrWidth) | address) << 8));
    Xil_Out32(evgInfo.baseAddr + REG_SEQ_GAP, delay);
    return 0;
}

int
ospreyEVGSequencerReadback(int bank, int address, uint32_t *delay)
{
    if (!evgInfo.baseAddr) return -1;
    if ((bank < 0) || (bank >= evgInfo.bankCount)
     || (address < 0) || (address >= (1 << evgInfo.seqAddrWidth))) return -2;
    Xil_Out32(evgInfo.baseAddr + REG_SEQ_ADDR_CODE,
                             (((bank << evgInfo.seqAddrWidth) | address) << 8));
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
    if ((rxIndex < 0) || (rxIndex >= evgInfo.rxCount)) return -2;
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
ospreyEVGSetHwTriggerInputMap(uint32_t bitmap)
{
    if (!evgInfo.baseAddr) return -1;
    Xil_Out32(evgInfo.baseAddr + REG_HW_TRIGGER_MAP, bitmap);
    return 0;
}

uint32_t
ospreyEVGGetHwTriggerInputMap(void)
{
    if (!evgInfo.baseAddr) return -1;
    return Xil_In32(evgInfo.baseAddr + REG_HW_TRIGGER_MAP);
}

int
ospreyEVGSetDbusInputMap(uint32_t bitmap)
{
    if (!evgInfo.baseAddr) return -1;
    Xil_Out32(evgInfo.baseAddr + REG_DBUS_MAP, bitmap);
    return 0;
}

uint32_t
ospreyEVGGetDbusInputMap(void)
{
    if (!evgInfo.baseAddr) return -1;
    return Xil_In32(evgInfo.baseAddr + REG_DBUS_MAP);
}

/*
 * FEED I/O support
 */
#define F_REG_STATUS                      0
#define F_REG_CONFIG                      1
#define F_REG_HEARTBEAT_DIVISOR           2
#define F_REG_SOFTWARE_EVENT              3
#define F_REG_SEQ_ARM                     4
#define F_REG_SEQ_DISARM                  5
#define F_REG_SEQ_TRIGGER                 6
#define F_REG_SEQ_CANCEL                  7
#define F_REG_HW_TRIGGER_INPUT_MAP        8
#define F_REG_DBUS_INPUT_MAP              9
#define F_REG_TIMER_EVENT_BASE            100
#define F_REG_TIMER_DIVISOR_BASE          120
#define F_REG_HWTRIGGER_EVENT_BASE        140
#define F_REG_SEQ_HWTRIGGER_CONFIG_BASE   180
#define F_REG_LATENCY_READBACK_BASE       200
#define F_REG_SEQ_PATTERN_BASE            8192
#define SEQ_MAX_CAPACITY                 4096
#define SEQ_MAX_BANKS                    8

int
ospreyEVG_FEEDwrite(int offset, uint32_t value)
{
    int idx;
    if (!evgInfo.baseAddr) return -1;
    switch(offset) {
    case F_REG_HEARTBEAT_DIVISOR:ospreyEVGSetHeartbeatDivisor(value);  return 0;
    case F_REG_SOFTWARE_EVENT:   ospreyEVGSendSoftwareEvent(value);    return 0;
    case F_REG_SEQ_ARM:          ospreyEVGSequencerArm(value);         return 0;
    case F_REG_SEQ_DISARM:       ospreyEVGSequencerDisarm(value);      return 0;
    case F_REG_SEQ_TRIGGER:      ospreyEVGSequencerSoftTrigger(value); return 0;
    case F_REG_SEQ_CANCEL:       ospreyEVGSequencerCancel();           return 0;
    case F_REG_HW_TRIGGER_INPUT_MAP:
                                 ospreyEVGSetHwTriggerInputMap(value); return 0;
    case F_REG_DBUS_INPUT_MAP:   ospreyEVGSetDbusInputMap(value);      return 0;
    }
    idx = offset - F_REG_HWTRIGGER_EVENT_BASE;
    if ((idx >= 0) && (idx < (2*evgInfo.hwTriggerCount))) {
        int hwTriggerIndex = idx >> 1;
        int edge = idx & 0x1;
        ospreyEVGSetHwTriggerEvent(hwTriggerIndex, edge, value);
        return 0;
    }
    idx = offset - F_REG_TIMER_EVENT_BASE;
    if ((idx >= 0) && (idx < evgInfo.timerCount)) {
        ospreyEVGSetTimerEvent(idx, value);
        return 0;
    }
    idx = offset - F_REG_TIMER_DIVISOR_BASE;
    if ((idx >= 0) && (idx < evgInfo.timerCount)) {
        ospreyEVGSetTimerDivisor(idx, value);
        return 0;
    }
    idx = offset - F_REG_SEQ_HWTRIGGER_CONFIG_BASE;
    if ((idx >= 0) && (idx < (2*evgInfo.hwTriggerCount))) {
        int bank = idx >> 1;
        int edge = idx & 0x1;
        ospreyEVGSequencerSetHwTrigger(bank, edge, value);
        return 0;
    }
    idx = offset - F_REG_SEQ_PATTERN_BASE;
    if ((idx >= 0) && (idx < (SEQ_MAX_BANKS*SEQ_MAX_CAPACITY*2))) {
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
    return -1;
}

uint32_t
ospreyEVG_FEEDread(int offset)
{
    int idx;
    if (!evgInfo.baseAddr) return -1;
    switch(offset) {
    case F_REG_STATUS:               return ospreyEVGStatus();
    case F_REG_CONFIG:               return ospreyEVGConfiguration();
    case F_REG_HW_TRIGGER_INPUT_MAP: return ospreyEVGGetHwTriggerInputMap();
    case F_REG_DBUS_INPUT_MAP:       return ospreyEVGGetDbusInputMap();
    }
    idx = offset - F_REG_LATENCY_READBACK_BASE;
    if ((idx >= 0) && (idx < 32)) {
        return ospreyEVGLatencyReadback(idx);
    }
    return 0;
}
