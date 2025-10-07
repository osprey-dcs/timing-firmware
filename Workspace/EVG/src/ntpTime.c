/*
 * MIT License
 *
 * Copyright (c) 2023 Osprey DCS
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
 * Event generator time source (NTP client)
 */
#include <stdio.h>
#include <ospreyEVG.h>
#include <ospreyUDP.h>
#include "gpio.h"
#include "ntpTime.h"
#include "systemParameters.h"
#include "util.h"

#define STARTUP_PAUSE_USEC 500000

#define NTP_POSIX_OFFSET 2208988800UL /* 1970 - 1900 in seconds */
#define NTP_PORT 123

/*
 * NTP packet
 * Use 8 bit arrays for multi-byte values to avoid endian issues
 */
#define NTP_FLAGS_LI_MASK       0xC0
#define NTP_FLAGS_LI_SHIFT      6
#define NTP_FLAGS_VERSION_MASK  0x38
#define NTP_FLAGS_VERSION_SHIFT 3
#define NTP_FLAGS_MODE_MASK     0x07
#define NTP_FLAGS_MODE_SHIFT    0
#define NTP_VERSION_3           (3 << NTP_FLAGS_VERSION_SHIFT)
#define NTP_MODE_CLIENT         (3 << NTP_FLAGS_MODE_SHIFT)
typedef struct ntpTimestamp {
    uint8_t secondsSinceEpoch[4];
    uint8_t fraction[4];
} ntpTimestamp;
struct ntpPacket {
    uint8_t      flags;
    uint8_t      stratum;
    uint8_t      poll;
    int8_t       precision;
    uint8_t      rootDelay[4];
    uint8_t      rootDispersion[4];
    uint8_t      referenceClockIdentifier[4];
    ntpTimestamp referenceTimestamp;
    ntpTimestamp originateTimestamp;
    ntpTimestamp receiveTimestamp;
    ntpTimestamp transmitTimestamp;
};

struct posixTime {
    uint32_t posixSeconds;
    uint32_t fraction;
};
static struct posixTime posixTime;
static uint32_t usecWhenQueried;
static ospreyUDPendpoint endpoint;

static void
ntpToPosix(struct posixTime *pt, ntpTimestamp *t)
{
    pt->posixSeconds = ((t->secondsSinceEpoch[0] << 24) |
                        (t->secondsSinceEpoch[1] << 16) |
                        (t->secondsSinceEpoch[2] <<  8) |
                         t->secondsSinceEpoch[3]) - NTP_POSIX_OFFSET;
    pt->fraction = (t->fraction[0] << 24) |
                   (t->fraction[1] << 16) |
                   (t->fraction[2] <<  8) |
                    t->fraction[3];
}

static void
showTimestamp(const char *name, ntpTimestamp *t)
{
    struct posixTime pt;
    ntpToPosix(&pt, t);
    printf("%10s: %u %u\n", name, pt.posixSeconds, pt.fraction);
}

static void
showPacket(struct ntpPacket *ntp)
{
    printf("LI:%d VERS:%d MODE:%d STRATUM:%d POLL:%d PRECISION:%d\n",
                     ntp->flags >> 6, (ntp->flags >> 3) & 0x7, ntp->flags & 0x7,
                     ntp->stratum, ntp->poll, ntp->precision);
    showTimestamp("Reference", &ntp->referenceTimestamp);
    showTimestamp("Originate", &ntp->originateTimestamp);
    showTimestamp("Receive", &ntp->receiveTimestamp);
    showTimestamp("Transmit", &ntp->transmitTimestamp);
}

static void
callback(ospreyUDPendpoint endpoint, uint32_t farAddress, int farPort,
                                                    const char *buf, int length)
{
    struct ntpPacket *ntp = (struct ntpPacket *)buf;
    uint32_t interval = microsecondsSinceBoot() - usecWhenQueried;
    if ((length >= sizeof(*ntp))
     && (posixTime.posixSeconds == 0)) {
        if (interval > 100000) {
            printf("NTP round trip %u us\n", interval);
        }
        ntpToPosix(&posixTime, &ntp->transmitTimestamp);
    }
    if (debugFlags & DEBUGFLAG_NTP) {
        printf("Received NTP %d, %u us\n", length, interval);
        if (length >= sizeof(*ntp)) {
            showPacket(ntp);
        }
    }
}

static struct ntpPacket query;
void
ntpQuery(void)
{
    uint32_t secondsSinceBoot = GPIO_READ(GPIO_IDX_SECONDS_SINCE_BOOT);
    if (endpoint == NULL) return;
    secondsSinceBoot += NTP_POSIX_OFFSET;
    posixTime.posixSeconds = 0;
    query.flags   = NTP_VERSION_3 | NTP_MODE_CLIENT,
    query.stratum = 16, /* Unsynchronized */
    query.poll    = 3,  /* 8 second interval */
    query.originateTimestamp.secondsSinceEpoch[0] = secondsSinceBoot>>24;
    query.originateTimestamp.secondsSinceEpoch[1] = secondsSinceBoot>>16;
    query.originateTimestamp.secondsSinceEpoch[2] = secondsSinceBoot>>8;
    query.originateTimestamp.secondsSinceEpoch[3] = secondsSinceBoot;
    usecWhenQueried = microsecondsSinceBoot();
    ospreyUDPsendto(endpoint, systemParameters.ntpServer, NTP_PORT,
                                                   (char*)&query, sizeof query);
}

/*
 * Event generator state machine
 */
static enum ntpState {
    ntpStart,
    ntpDelay,
    ntpBeginResync,
    ntpAwaitPPS,
    ntpAwaitNTP,
    ntpPause,
    ntpSynced,
    ntpFatal } ntpState = ntpStart;

static int
ntpInit(void)
{
    if (systemParameters.ntpServer == 0) {
        printf("NTP Server not specified!\n");
        return -1;
    }
    endpoint = ospreyUDPregisterEndpoint(NTP_PORT, callback);
    if (endpoint == NULL) {
        printf("CRITICAL WARNING -- CAN'T CREATE NTP CLIENT!\n");
        return -2;
    }
    return 0;
}

static void
ntpCrank(void)
{
    uint32_t ppsValid = ospreyEVGStatus() & OSPREY_EVG_STATUS_PPS_VALID;
    int ppsToggle = ospreyEVGGetPPStoggle();
    enum ntpState oldState = ntpState;
    static int oldPPStoggle;
    static uint32_t then;
    static int reportedMissingPPS;

    switch (ntpState) {
    case ntpStart:
        // Lazy initialization
        if (ntpInit() < 0) {
            ntpState = ntpFatal;
        }
        // Issue an an initial query to get the ARP out of the way
        ntpQuery();
        then = microsecondsSinceBoot();
        ntpState = ntpDelay;
        break;

    case ntpDelay:
        // Let things settle down
        if ((microsecondsSinceBoot() - then) > STARTUP_PAUSE_USEC){
            ntpState = ntpBeginResync;
        }
        break;

    case ntpBeginResync:
        reportedMissingPPS = 0;
        oldPPStoggle = ppsToggle;
        then = microsecondsSinceBoot();
        ntpState = ntpAwaitPPS;
        break;

    case ntpAwaitPPS:
        if (ppsValid && (ppsToggle != oldPPStoggle)) {
            if (reportedMissingPPS) {
                printf("PPS present, continuing with synchronization.\n");
                reportedMissingPPS = 0;
            }
            ntpQuery();
            then = microsecondsSinceBoot();
            ntpState = ntpAwaitNTP;
        }
        else if ((microsecondsSinceBoot() - then) > 1100000) {
            then = microsecondsSinceBoot();
            if (!reportedMissingPPS++) {
                printf("Warning -- invalid PPS.\n");
            }
            if ((reportedMissingPPS % 60) == 0) {
                printf("Still no PPS.\n");
            }
        }
        break;

    case ntpAwaitNTP:
        if (posixTime.posixSeconds) {
            printf("Time %u:%u after %u us\n", posixTime.posixSeconds,
                                               posixTime.fraction,
                                               microsecondsSinceBoot()-then);
            if (posixTime.fraction > (1UL << 30)) {
                printf("Warning -- PPS marker to NTP second %d ms.\n",
                                     ((posixTime.fraction >> 10) * 1000) >> 22);
            }
            ntpState = ntpSynced;
            break;
        }
        else if ((microsecondsSinceBoot() - then) > 800000) {
            printf("Warning -- No response from NTP server.\n");
            ntpState = ntpPause;
        }
        break;

    case ntpPause:
        if ((microsecondsSinceBoot() - then) > ((1<<query.poll) * 1000000)) {
            then = microsecondsSinceBoot();
            ntpState = ntpAwaitPPS;
        }
        break;

    case ntpSynced:
        break;

    case ntpFatal:
        break;
    }
    oldPPStoggle = ppsToggle;
    if ((debugFlags & DEBUGFLAG_NTP) && (ntpState != oldState)) {
        printf("NTP State %d\n", ntpState);
    }
}

uint32_t
ntpNewTime(void)
{
    uint32_t seconds = 0;
    if (ntpState == ntpSynced) {
        ntpState = ntpBeginResync;
    }
    ntpCrank();
    if (ntpState == ntpSynced) {
        seconds = posixTime.posixSeconds;
        posixTime.posixSeconds = 0;
    }
    return seconds;
}

