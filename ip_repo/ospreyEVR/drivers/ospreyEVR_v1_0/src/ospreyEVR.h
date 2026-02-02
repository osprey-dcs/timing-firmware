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

#ifndef _OSPREYEVR_H_
#define _OSPREYEVR_H_

/*
 * Basic MRF-compatible event receiver
 */

#include <stdint.h>

#define OSPREY_EVR_STATUS_TRISTATE_MASK         0xFFFC000
#define OSPREY_EVR_STATUS_TRISTATE_SHIFT        14
#define OSPREY_EVR_STATUS_ACTIVE_LOW_OUTPUTS    0x2000
#define OSPREY_EVR_STATUS_SERDES_FACTOR_MASK    0x1E00
#define OSPREY_EVR_STATUS_SERDES_FACTOR_SHIFT   9
#define OSPREY_EVR_STATUS_OUTPUT_COUNT_MASK     0x1F0
#define OSPREY_EVR_STATUS_OUTPUT_COUNT_SHIFT    4
#define OSPREY_EVR_STATUS_FIFO_OVERFLOW         0x08
#define OSPREY_EVR_STATUS_FIFO_PENDING          0x04
#define OSPREY_EVR_STATUS_TIMESTAMP_VALID       0x02
#define OSPREY_EVR_STATUS_LINK_UP               0x01

#define OSPREY_EVR_ACTION_WRITE_FIFO        0x20000
#define OSPREY_EVR_ACTION_INTERRUPT         0x10000

int ospreyEVRInit(uint32_t baseAddress);
int ospreyEVRStatus(void);
int ospreyEVRSetEventAction(int event, int action);
int ospreyEVRSelectOutputSource(int channel, int source);
int ospreyEVRSetPulseDelay(int channel, uint32_t delay);
int ospreyEVRSetPulseWidth(int channel, uint32_t width);
int ospreyEVRGetTime(uint32_t *seconds, uint32_t *ticks);
int ospreyEVRGetFifoEvent(uint32_t *seconds, uint32_t *ticks);

int ospreyEVR_FEEDwrite(int offset, uint32_t value);
uint32_t ospreyEVR_FEEDread(int offset);

#endif /* _OSPREYEVR_H_ */
