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

/** @file ospreyEVG.h
 *
 * Basic MRF-compatible event generator
 *
 * See documentation/ospreyEVG.md
 */

#include <stdint.h>

// REG_IDX_CSR
//! The index (1-based) of the active, or previously-active, sequencer.
//! Zero value if no sequencer bank is running
#define OSPREY_EVG_STATUS_SEQ_ACTIVE            0x800000
#define OSPREY_EVG_STATUS_ACTIVE_BANK_MASK      0x700000
#define OSPREY_EVG_STATUS_ACTIVE_BANK_SHIFT     20
//! Bitmap of triggered sequencers
//! (not yet active because another sequence is still running).
//!  Bit 0 corresponds to the first sequencer.
#define OSPREY_EVG_STATUS_TRIGGERED_BANKS_MASK  0xFF000
#define OSPREY_EVG_STATUS_TRIGGERED_BANKS_SHIFT 12
//! Bitmap of armed sequencers.  Bit 0 corresponds to the first sequencer.
#define OSPREY_EVG_STATUS_ARMED_BANKS_MASK      0xFF0
#define OSPREY_EVG_STATUS_ARMED_BANKS_SHIFT     4
//! Toggles on rising edge of pulse-per-second marker.
#define OSPREY_EVG_STATUS_PPS_TOGGLE            0x4
/** Set when the event generator time stamp seconds are valid.
 *  This bit will remain cleared until the pulse-per-second marker is valid
 *  and the POSIX seconds have been set.
 *  An invalid pulse-per-second marker will clear this bit until
 *  the pulse-per-second marker is valid and the POSIX seconds have
 *  again been set.
 */
#define OSPREY_EVG_STATUS_TIME_VALID            0x2
//! Set when the pulse-per-second marker is valid.
#define OSPREY_EVG_STATUS_PPS_VALID             0x1

// REG_IDX_CONFIG
#define OSPREY_EVG_CONFIG_RX_COUNT_MASK         0xF00000
#define OSPREY_EVG_CONFIG_RX_COUNT_SHIFT        20
#define OSPREY_EVG_CONFIG_SEQ_ADDR_WIDTH_MASK   0x0F0000
#define OSPREY_EVG_CONFIG_SEQ_ADDR_WIDTH_SHIFT  16
#define OSPREY_EVG_CONFIG_BANK_COUNT_MASK       0x00F000
#define OSPREY_EVG_CONFIG_BANK_COUNT_SHIFT      12
#define OSPREY_EVG_CONFIG_TIMER_COUNT_MASK      0x000F00
#define OSPREY_EVG_CONFIG_TIMER_COUNT_SHIFT     8
#define OSPREY_EVG_CONFIG_HW_TRIG_COUNT_MASK    0x0000FF
#define OSPREY_EVG_CONFIG_HW_TRIG_COUNT_SHIFT   0

// REG_TIMER_CSR
#define TIMER_CMD_NOP    0
#define TIMER_CMD_STOP   1
#define TIMER_CMD_RESUME 2
#define TIMER_CMD_START  3

//! HDL Parameters of core instance
typedef struct {
    uint8_t hwTriggerCount; //!< XPAR_OSPREYEVG_INPUT_COUNT
    uint8_t timerCount;     //!< XPAR_OSPREYEVG_TIMER_COUNT
    uint8_t bankCount;      //!< XPAR_OSPREYEVG_SEQRAM_BANK_COUNT
    uint8_t seqAddrWidth;   //!< XPAR_OSPREYEVG_SEQRAM_ADDR_WIDTH
    uint8_t rxCount;        //!< XPAR_OSPREYEVG_RX_COUNT
} evgConfigInfo;


/** Initialize core
 *
 * @param baseAddress eg. XPAR_OSPREYEVG_S_AXI_BASEADDR
 * @return 0 on success
 *
 * An application must initialize the the hardware interface before calling
 * any of the other routines.
 *
 * The return value is 0 if registration succeeded and -1 otherwise.  If
 * the block design component name is ospreyEVG the memory-mapped I/O base
 * address to pass as the argument will be defined in the board support
 * `xparameters.h` file as `XPAR_OSPREYEVG_S_AXI_BASEADDR` or
 * `XPAR_OSPREYEVG_#_S_AXI_BASEADDR`.
 */
int ospreyEVGInit(uint32_t baseAddress);
/** Core status bit-field
 * @returns a bit mask testable with the OSPREY_EVG_STATUS_* macros
 */
int ospreyEVGStatus(void);
//! Inspect core parameters in effect
const evgConfigInfo* ospreyEVGGetConf(void);
int ospreyEVGGetPPStoggle(void);
/** Queue a new POSIX seconds value to be distributed after the next PPS event.
 *
 * Must be called once to initialize.  Afterwards, will be incremented by one
 * for each PPS.
 * May be called repeatedly to handle time changes.
 * @return 0 or negative on error
 */
int ospreyEVGSetSeconds(uint32_t posixSeconds);
//! The rate at which heartbeat events (code 0x7A) are generated is the evgClk divided.
int ospreyEVGSetHeartbeatDivisor(uint32_t divisor);
/** Start/stop control for timers
 * @param control A bit mask with 2 bits assigned to each timer.
 *        Each 2 bits may be one of the TIMER_CMD_*
 * @return 0 or negative on error
 */
int ospreyEVGSetTimerControl(uint32_t control);
/** Timer status bit mask.
 * @return A bit mask with 2 bits assigned to each timer
 * @return 0 or negative on error
 */
int ospreyEVGGetTimerStatus(void);
/** Set event code for a timer
 * @param timerIndex 0 through evgConfigInfo::timerCount-1
 * @param evCode 0 through 255.  0 disables.
 * @return 0 or negative on error
 */
int ospreyEVGSetTimerEvent(int timerIndex, int evCode);
/** Set timer divisor from reference clock frequency
 * @param timerIndex
 * @param divisor from 41 through 0xffffffff
 * @return 0 or negative on error
 */
int ospreyEVGSetTimerDivisor(int timerIndex, uint32_t divisor);
/** Configure input edge event
 * @param hwTriggerIndex 0 thorugh evgConfigInfo::hwTriggerCount-1
 * @param edge 0 rising edge, 1 falling edge
 * @param evCode 0 through 255.  0 disbles.
 * @return 0 or negative on error
 */
int ospreyEVGSetHwTriggerEvent(int hwTriggerIndex, int edge, int evCode);
//! Readback event code for input edge
int ospreyEVGGetHwTriggerEvent(int hwTriggerIndex, int edge);
//! An arbitrary event code is transmitted
int ospreyEVGSendSoftwareEvent(int evCode);
/** The mapping of inputs (hwInputs_a) to distributed bus bits
 *
 * @param bit Dbus bit 0 through 7
 * @param inputSel Input index 0 through evgConfigInfo::hwTriggerCount
 */
int ospreyEVGSetDbusInputMap(uint8_t bit, uint32_t inputSel);
//! Readback inputSel for a Dbus bit
uint32_t ospreyEVGGetDbusInputMap(uint8_t bit);

//! Arm sequencer banks (bit mask)
int ospreyEVGSequencerArm(int banks);
//! Disrm sequencer banks (bit mask)
int ospreyEVGSequencerDisarm(int banks);
/** Update event code in sequencer table
 * @param bank index 0 through evgConfigInfo::bankCount-1
 * @param address 0 through (1<<seqAddrWidth)-1
 * @param evCode 0 through 255.  0 takes no action.
 * @return 0 or negative on error
 */
int ospreyEVGSequencerWriteCode(int bank, int address, int evCode);
/** Update event delay in sequencer table
 * @param bank index 0 through evgConfigInfo::bankCount-1
 * @param address 0 through (1<<seqAddrWidth)-1
 * @param delay 0 through 0xffffffff in units of reference clock ticks.
 *        A delay of 0 will send on the next tick.
 * @return 0 or negative on error
 */
int ospreyEVGSequencerWriteDelay(int bank, int address, uint32_t delay);
/** Set sequencer bank trigger source from input edge(s)
 * @param bank index
 * @param edge 0 rising, 1 falling
 * @param hwTriggerBitmap bit mask of inputs.  hwTriggerCount bits.
 * @return 0 or negative on error
 */
int ospreyEVGSequencerSetHwTrigger(int bank, int edge, int hwTriggerBitmap);
/** Set sequencer bank trigger source from timers
 * @param bank index
 * @param edge 0 rising, 1 falling
 * @param timerBitmap bit mask of inputs.  timerCount bits.
 * @return 0 or negative on error
 */
int ospreyEVGSequencerSetTimerTrigger(int bank, int timerBitmap);
//! force bank(s) to trigger.  bit mask
int ospreyEVGSequencerSoftTrigger(int banks);
//! Immediately stop all sequencer banks
int ospreyEVGSequencerCancel(void);
/** Readback an entry from a sequencer table
 * @param bank index 0 through evgConfigInfo::bankCount-1
 * @param address 0 through (1<<seqAddrWidth)-1
 * @param delay 0 through 0xffffffff in units of reference clock ticks.
 *        A delay of 0 will send on the next tick.
 * @param delay If !NULL, delay written
 * @return Event code 0 through 255, or negative on error
 */
int ospreyEVGSequencerReadback(int bank, int address, uint32_t *delay);
/** The round-trip latency of an event link fiber and receiver hardware
 *
 * @param rxIndex 0 through bankCount-1
 *
 * The value returned is in units of 1/64th of the sampling clock interval.
 * Typically the sampling clock operates at 156.25 MHz (6.4 ns interval)
 * so one count of the returned value corresponds to a latency of 100 ps.
 */
int ospreyEVGLatencyReadback(int rxIndex);

int ospreyEVG_FEEDwrite(int offset, uint32_t value);
uint32_t ospreyEVG_FEEDread(int offset);

#endif /* _OSPREYEVG_H_ */
