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
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
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
 * GNSS NMEA parsing
 */

#ifndef _OSPREYGNSS_H_
#define _OSPREYGNSS_H_

#include <stdint.h>

#define GNSS_STATUS_MESSAGE_WATCHDOG    0x1000000
#define GNSS_STATUS_PPS_VALID           0x10000
#define GNSS_STATUS_TRANSMITTER_BUSY    0x100
#define GNSS_STATUS_RECEPTION_ENABLED   0x1

int ospreyGNSSInit(uint32_t address,
                 void (*timeCallback)(uint32_t posixSeconds, int milliseconds));
const char *ospreyGNSSPoll(void);

int ospreyGNSSEnableReception(int enable);

int ospreyGNSSStatus(void);
int ospreyGNSSsatellitesInView(void);

int ospreyGNSSSendByte(int c);

uint32_t ospreyGNSSPPScount(void);
uint32_t ospreyGNSSStartGlitchCount(void);
uint32_t ospreyGNSSFramingErrorCount(void);
uint32_t ospreyGNSSOverrunCount(void);
uint32_t ospreyGNSSBadMessageCount(void);
uint32_t ospreyGNSSChecksumErrorCount(void);

#endif /* _OSPREYGNSS_H_ */

