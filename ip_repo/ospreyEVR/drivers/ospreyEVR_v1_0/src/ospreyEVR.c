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
 * Basic MRF-compatible event receiver
 * Assume only one per processor
 */
#include <stdio.h>
#include <stdint.h>
#include <xil_io.h>
#include "ospreyEVR.h"

#define MAX_OUTPUTS 16

#define REG_OFFSET_CSR              (0*4)
#define REG_OFFSET_SECONDS          (2*4)
#define REG_OFFSET_TICKS            (3*4)
#define REG_OFFSET_ACTION           (4*4)
#define REG_OFFSET_FIFO_EVENT       (5*4)
#define REG_OFFSET_FIFO_SECONDS     (6*4)
#define REG_OFFSET_FIFO_TICKS       (7*4)
#define REG_OFFSET_OUTPUT_SELECT    (8*4)
#define REG_OFFSET_OUTPUT_CONTROL   (9*4)
#define REG_OFFSET_PULSE_DELAY     (10*4)
#define REG_OFFSET_PULSE_WIDTH     (11*4)

#define FIFO_EVENT_EVENT_PENDING 0x80000000
#define FIFO_EVENT_FIFO_OVERFLOW 0x40000000
#define FIFO_EVENT_EVENT_MASK    0xFF

struct evrInfo {
    uint32_t     baseAddr;
    int          outputCount;
    unsigned int serdesFactor;
    uint32_t     source[MAX_OUTPUTS];
    uint32_t     delays[MAX_OUTPUTS];
    uint32_t     widths[MAX_OUTPUTS];
};
static struct evrInfo evrInfo;

static void
setOutput(int output)
{
    uint32_t delay = evrInfo.delays[output];
    uint32_t width = evrInfo.widths[output];
    int mask = (1 << evrInfo.serdesFactor) - 1;
    uint32_t control;
    int firstWord, lastWord, delayCounter, widthCounter;
    uint32_t remainingWidth;
    int leadingZeros, trailingOnes;

    if (width < evrInfo.serdesFactor) width = evrInfo.serdesFactor;
    delayCounter = delay / evrInfo.serdesFactor;
    leadingZeros = delay % evrInfo.serdesFactor;
    remainingWidth = width - (evrInfo.serdesFactor - leadingZeros);
    trailingOnes = remainingWidth % evrInfo.serdesFactor;
    widthCounter = remainingWidth / evrInfo.serdesFactor;
    firstWord = (mask << leadingZeros) & mask;
    lastWord = mask >> (evrInfo.serdesFactor - trailingOnes);
    control = (evrInfo.source[output]<<16) | (lastWord<<8) | firstWord;
    Xil_Out32(evrInfo.baseAddr + REG_OFFSET_OUTPUT_SELECT, output);
    Xil_Out32(evrInfo.baseAddr + REG_OFFSET_OUTPUT_CONTROL, control);
    Xil_Out32(evrInfo.baseAddr + REG_OFFSET_PULSE_DELAY, delayCounter);
    Xil_Out32(evrInfo.baseAddr + REG_OFFSET_PULSE_WIDTH, widthCounter);
}

int
ospreyEVRInit(uint32_t baseAddress)
{
    uint32_t status;
    int outputCount;
    if (!baseAddress) return -1;
    evrInfo.baseAddr = baseAddress;
    status = ospreyEVRStatus();
    outputCount = (status & OSPREY_EVR_STATUS_OUTPUT_COUNT_MASK) >>
                                           OSPREY_EVR_STATUS_OUTPUT_COUNT_SHIFT;
    if ((outputCount < 2) || (outputCount > MAX_OUTPUTS)) return -2;
    evrInfo.outputCount = outputCount;
    evrInfo.serdesFactor = (status & OSPREY_EVR_STATUS_SERDES_FACTOR_MASK) >>
                                          OSPREY_EVR_STATUS_SERDES_FACTOR_SHIFT;
    return 0;
}

int
ospreyEVRStatus(void)
{
    if (!evrInfo.baseAddr) return -1;
    return Xil_In32(evrInfo.baseAddr + REG_OFFSET_CSR);
}

static
uint32_t shadow_actions[256];

int
ospreyEVRSetEventAction(int event, int action)
{
    if ((event <= 0) || (event >= 255)) return -1;
    shadow_actions[event] = action;
    Xil_Out32(evrInfo.baseAddr + REG_OFFSET_ACTION, (action << 8) | event);
    return 0;
}

static int
isValidOutput(int output)
{
    if ((output < 0)
     || (output >= evrInfo.outputCount)) return 0;
    return 1;
}

int
ospreyEVRSelectOutputSource(int output, int source)
{
    if (!isValidOutput(output)) return -1;
    evrInfo.source[output] = source;
    setOutput(output);
    return 0;
}

int
ospreyEVRSetPulseDelay(int output, uint32_t delay)
{
    if (!isValidOutput(output)) return -1;
    evrInfo.delays[output] = delay;
    setOutput(output);
    return 0;
}

int
ospreyEVRSetPulseWidth(int output, uint32_t width)
{
    if (!isValidOutput(output)) return -1;
    evrInfo.widths[output] = width;
    setOutput(output);
    return 0;
}

int
ospreyEVRGetTime(uint32_t *seconds, uint32_t *ticks)
{
    int status = ospreyEVRStatus();
    uint32_t s0, s1, t;
    int pass = 0;
    if ((status < 0)
     || ((status&(OSPREY_EVR_STATUS_TIMESTAMP_VALID|OSPREY_EVR_STATUS_LINK_UP))
            != (OSPREY_EVR_STATUS_TIMESTAMP_VALID|OSPREY_EVR_STATUS_LINK_UP))) {
        return -1;
    }
    s0 = Xil_In32(evrInfo.baseAddr+REG_OFFSET_SECONDS);
    for (;;) {
        t = Xil_In32(evrInfo.baseAddr+REG_OFFSET_TICKS);
        s1 = Xil_In32(evrInfo.baseAddr+REG_OFFSET_SECONDS);
        if (s0 == s1) {
            if (seconds) *seconds = s1;
            if (ticks) *ticks = t;
            return 0;
        }
        if (++pass == 5) return -2;
        s0 = s1;
    }
}

int
ospreyEVRGetFifoEvent(uint32_t *seconds, uint32_t *ticks)
{
    uint32_t eventReg;
    if (!evrInfo.baseAddr) return 0;
    eventReg = Xil_In32(evrInfo.baseAddr+REG_OFFSET_FIFO_EVENT);
    if ((eventReg & FIFO_EVENT_EVENT_PENDING) == 0) {
        if (seconds)
            *seconds = 0;
        if (ticks)
            *ticks = 0;
        return 0;
    }
    if (seconds) {
        *seconds = Xil_In32(evrInfo.baseAddr+REG_OFFSET_FIFO_SECONDS);
    }
    if (ticks) {
        *ticks = Xil_In32(evrInfo.baseAddr+REG_OFFSET_FIFO_TICKS);
    }
    return eventReg & FIFO_EVENT_EVENT_MASK;
}

/*
 * FEED I/O support
 */
#define REG_STATUS                      0
#define REG_NOW                         1
// ... 2
#define REG_ACTIONS_BASE              100
#define REG_OUTPUT_SELECT_BASE        400
#define REG_PULSE_DELAY_BASE          420
#define REG_PULSE_WIDTH_BASE          440

// (1<<8) == 3*85 + 1
#define REG_EVNT_LOG                  500
// ... 756

int
ospreyEVR_FEEDwrite(int offset, uint32_t value)
{
    int idx;
    if (!evrInfo.baseAddr) return -1;
    idx = offset - REG_ACTIONS_BASE;
    if ((idx > 0) && (idx < 255)) {
        ospreyEVRSetEventAction(idx, value);
        return 0;
    }
    idx = offset - REG_OUTPUT_SELECT_BASE;
    if ((idx >= 0) && (idx < evrInfo.outputCount)) {
        ospreyEVRSelectOutputSource(idx, value);
        return 0;
    }
    idx = offset - REG_PULSE_DELAY_BASE;
    if ((idx >= 0) && (idx < evrInfo.outputCount)) {
        ospreyEVRSetPulseDelay(idx, value);
        return 0;
    }
    idx = offset - REG_PULSE_WIDTH_BASE;
    if ((idx >= 0) && (idx < evrInfo.outputCount)) {
        ospreyEVRSetPulseWidth(idx, value);
        return 0;
    }
    return -1;
}

uint32_t
ospreyEVR_FEEDread(int offset)
{
    if (!evrInfo.baseAddr) return -1;
    static uint32_t now_nsec;
    static uint32_t log_sec, log_nsec;

    switch(offset) {
    case REG_STATUS:       return ospreyEVRStatus();
    case REG_NOW: {
        uint32_t sec=now_nsec=0;
        (void)ospreyEVRGetTime(&sec, &now_nsec);
        return sec;
    }
    case REG_NOW+1:
        return now_nsec;
    case REG_EVNT_LOG:
        return 0xdeadbeef;
    }

    int idx;
    idx = offset - REG_EVNT_LOG;
    if ((idx > 0) && (idx < 256)) {
        switch(idx%3u) {
        case 1:
            return ospreyEVRGetFifoEvent(&log_sec, &log_nsec);
        case 2:
            return log_sec;
        case 0:
            return log_nsec;
        }
        return 0;
    }
    idx = offset - REG_ACTIONS_BASE;
    if ((idx > 0) && (idx < 255)) {
        return shadow_actions[idx];
    }
    idx = offset - REG_OUTPUT_SELECT_BASE;
    if ((idx >= 0) && (idx < evrInfo.outputCount)) {
        return evrInfo.source[idx];
    }
    idx = offset - REG_PULSE_DELAY_BASE;
    if ((idx >= 0) && (idx < evrInfo.outputCount)) {
        return evrInfo.delays[idx];
    }
    idx = offset - REG_PULSE_WIDTH_BASE;
    if ((idx >= 0) && (idx < evrInfo.outputCount)) {
        return evrInfo.widths[idx];
    }

    return 0;
}
