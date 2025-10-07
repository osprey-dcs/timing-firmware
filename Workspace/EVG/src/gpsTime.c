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
 * Get time of day from NMEA GPS receiver
 */
#include <stdio.h>
#include <stdint.h>
#include <xuartlite_l.h>
#include <xparameters.h>
#include <ospreyGNSS.h>
#include "gpsTime.h"
#include "util.h"

static uint32_t newTimePosixSeconds;

static void
timeCallback(uint32_t posixSeconds, int milliseconds)
{
    newTimePosixSeconds = posixSeconds;
    printf("GNSS TIME:%d.%03d Satellites:%d\n", posixSeconds, milliseconds,
                                                  ospreyGNSSsatellitesInView());
}

uint32_t
gpsNewTime(void)
{
    uint32_t csr = ospreyGNSSStatus();
    static int firstTime = 1;
    if (firstTime) {
        ospreyGNSSInit(XPAR_OSPREYGNSS_AXI_BASEADDR, timeCallback);
        firstTime = 0;
    }
    if (csr & GNSS_STATUS_RECEPTION_ENABLED) {
        const char *cp = ospreyGNSSPoll();
        if ((debugFlags & DEBUGFLAG_NMEA) && (cp != NULL)) {
            printf("NMEA: %s\n", cp);
        }
        if (newTimePosixSeconds) {
            ospreyGNSSEnableReception(0);
            return newTimePosixSeconds;
        }
    }
    else {
        newTimePosixSeconds = 0;
        ospreyGNSSEnableReception(1);
    }
    return 0;
}
