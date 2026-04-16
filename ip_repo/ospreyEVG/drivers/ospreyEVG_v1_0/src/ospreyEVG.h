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

#ifndef _OSPREYEVG_H_
#define _OSPREYEVG_H_

/*
 * Basic MRF-compatible event generator
 */

#include <stdint.h>

#define OSPREY_EVG_STATUS_SEQ_ACTIVE            0x800000
#define OSPREY_EVG_STATUS_ACTIVE_BANK_MASK      0x700000
#define OSPREY_EVG_STATUS_ACTIVE_BANK_SHIFT     20
#define OSPREY_EVG_STATUS_TRIGGERED_BANKS_MASK  0xFF000
#define OSPREY_EVG_STATUS_TRIGGERED_BANKS_SHIFT 12
#define OSPREY_EVG_STATUS_ARMED_BANKS_MASK      0xFF0
#define OSPREY_EVG_STATUS_ARMED_BANKS_SHIFT     4
#define OSPREY_EVG_STATUS_PPS_TOGGLE            0x4
#define OSPREY_EVG_STATUS_TIME_VALID            0x2
#define OSPREY_EVG_STATUS_PPS_VALID             0x1

#define OSPREY_EVG_CONFIG_RX_COUNT_MASK         0xF0000
#define OSPREY_EVG_CONFIG_RX_COUNT_SHIFT        16
#define OSPREY_EVG_CONFIG_SEQ_ADDR_WIDTH_MASK   0xF000
#define OSPREY_EVG_CONFIG_SEQ_ADDR_WIDTH_SHIFT  12
#define OSPREY_EVG_CONFIG_BANK_COUNT_MASK       0xF00
#define OSPREY_EVG_CONFIG_BANK_COUNT_SHIFT      8
#define OSPREY_EVG_CONFIG_TIMER_COUNT_MASK      0xF0
#define OSPREY_EVG_CONFIG_TIMER_COUNT_SHIFT     4
#define OSPREY_EVG_CONFIG_HW_TRIG_COUNT_MASK    0xF
#define OSPREY_EVG_CONFIG_HW_TRIG_COUNT_SHIFT   0


int ospreyEVGInit(uint32_t baseAddress);
int ospreyEVGStatus(void);
int ospreyEVGConfiguration(void);
int ospreyEVGGetPPStoggle(void);
int ospreyEVGSetSeconds(uint32_t posixSeconds);
int ospreyEVGSetHeartbeatDivisor(uint32_t divisor);
int ospreyEVGSetTimerControl(uint32_t control);
int ospreyEVGGetTimerStatus(void);
int ospreyEVGSetTimerEvent(int timerIndex, int evCode);
int ospreyEVGSetTimerDivisor(int timerIndex, uint32_t divisor);
int ospreyEVGSetHwTriggerEvent(int hwTriggerIndex, int edge, int evCode);
int ospreyEVGSendSoftwareEvent(int evCode);
int ospreyEVGSetHwTriggerInputMap(uint32_t bitmap);
int ospreyEVGSetDbusInputMap(uint32_t bitmap);
uint32_t ospreyEVGGetHwTriggerInputMap(void);
uint32_t ospreyEVGGetDbusInputMap(void);

int ospreyEVGSequencerArm(int banks);
int ospreyEVGSequencerDisarm(int banks);
int ospreyEVGSequencerWriteCode(int bank, int address, int evCode);
int ospreyEVGSequencerWriteDelay(int bank, int address, uint32_t delay);
int ospreyEVGSequencerSetHwTrigger(int bank, int edge, int hwTriggerBitmap);
int ospreyEVGSequencerSoftTrigger(int banks);
int ospreyEVGSequencerCancel(void);
int ospreyEVGSequencerReadback(int bank, int address, uint32_t *delay);
int ospreyEVGLatencyReadback(int rxIndex);

int ospreyEVG_FEEDwrite(int offset, uint32_t value);
uint32_t ospreyEVG_FEEDread(int offset);

#endif /* _OSPREYEVG_H_ */
