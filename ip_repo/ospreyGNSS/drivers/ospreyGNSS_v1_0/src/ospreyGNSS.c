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

#include <ctype.h>
#include <xil_io.h>
#include "ospreyGNSS.h"

#define REG_IDX_CSR                  (0*4)
#define REG_IDX_PPS_COUNT            (1*4)
#define REG_IDX_RX_FIFO              (2*4)
#define REG_IDX_START_GLITCH_COUNT   (3*4)
#define REG_IDX_FRAMING_ERROR_COUNT  (4*4)
#define REG_IDX_OVERRUN_COUNT        (5*4)
#define REG_IDX_BAD_MESSAGE_COUNT    (6*4)
#define REG_IDX_CHECKSUM_ERROR_COUNT (7*4)

#define CSR_W_ENABLE_RECEPTION      0x1
#define CSR_W_DISABLE_RECEPTION     0x2

#define RX_FIFO_EMPTY       0x80000000
#define RX_FIFO_CHAR_MASK   0xFF

static struct gnssInfo {
    uint32_t baseAddress;
    int      satellitesInView;
    void     (*timeCallback)(uint32_t posixSeconds, int milliseconds);
} gnss = { .satellitesInView = -1 };

int
ospreyGNSSInit(uint32_t address,
                  void (*timeCallback)(uint32_t posixSeconds, int milliseconds))
{
    if (!address) return -1;
    gnss.baseAddress = address;
    gnss.timeCallback = timeCallback;
    return 0;
}

/*
 * Returns number of days since civil 1970-01-01
 * Ref: https://howardhinnant.github.io/date_algorithms.html#days_from_civil
 */
static int
days_from_civil(int y, unsigned m, unsigned d)
{
    y -= m <= 2;
    const int era = (y >= 0 ? y : y-399) / 400;
    const unsigned yoe = (y - era * 400);                         // [0, 399]
    const unsigned doy = (153*(m + (m > 2 ? -3 : 9)) + 2)/5 + d-1;// [0, 365]
    const unsigned doe = yoe * 365 + yoe/4 - yoe/100 + doy;       // [0, 146096]
    return era * 146097 + doe - 719468;
}

static int
decval(char c)
{
    if ((c >= '0') && (c <= '9')) return c - '0';
    return -1;
}

static void
consume(char c)
{
    static const char *fmt = "";
    static int value;
    static int nFrac;
    static int vIdx = 0;
    static int vBuf[7]; /* hh, mm, ss, ms, DD, MM, YY */
    int v;

    if (c == '$') {
        fmt = "GPx";
        vIdx = 0;
        return;
    }
    if (c == '*') {
        if (*fmt == '\0') {
            switch (vIdx) {
            case 1:
                gnss.satellitesInView = vBuf[0];
                break;

            case 7:
                if (gnss.timeCallback) {
                    int y = vBuf[6] + (vBuf[6] < 20 ? 2100 : 2000);
                    (*gnss.timeCallback)(days_from_civil(y, vBuf[5], vBuf[4]) *
                                                            86400 +
                                                            vBuf[0] * 3600 +
                                                            vBuf[1] * 60 +
                                                            vBuf[2],
                                                            vBuf[3] * 4294967U);
                }
                break;
            }
        }
        fmt = "!";
        return;
    }
    switch (*fmt) {
    case 'x':
        switch(c) {
        case 'R': fmt = "MC,hlhlhl.f,a,,,,,,,hlhlhl"; break;
        case 'G': fmt = "SV,,,hl";                  break;
        default:  fmt = "";                         break;
        }
        break;

    case 'h':
    case 'l':
        if ((v = decval(c)) < 0) {
            fmt = "!";
            return;
        }
        if (*fmt == 'h') {
            value = v * 10;
        }
        else {
            value += v;
            vBuf[vIdx++] = value;
        }
        fmt++;
        break;

    case '.':
        if (c == '.') {
            value = 0;
            nFrac = 0;
            fmt++;
        }
        else {
            vBuf[vIdx++] = -1;
            fmt += 2;
            consume(c);
        }
        break;

    case 'f':
        if ((v = decval(c)) >= 0) {
            if (++nFrac <= 3) {
                value = value * 10 + v;
            }
        }
        else {
            while (nFrac < 3) {
                nFrac++;
                value *= 10;
            }
            vBuf[vIdx++] = value;
            fmt++;
            consume(c);
        }
        break;

    case 'a':
        if (c != 'A') {
            fmt = "!";
            return;
        }
        fmt++;
        break;

    case ',':
        if (c == ',') {
            fmt++;
        }
        break;

    default:
        if (c != *fmt++) {
            fmt = "";
        }
        break;
    }
}

int
ospreyGNSSsatellitesInView(void)
{
    return gnss.satellitesInView;
}

const char *
ospreyGNSSPoll(void)
{
    uint32_t r;
    const char *ret = NULL;
    static char msgBuf[100];
    static unsigned int msgIndex;
    if (!gnss.baseAddress) return NULL;
    r = Xil_In32(gnss.baseAddress+REG_IDX_RX_FIFO);
    if ((r & RX_FIFO_EMPTY) == 0) {
        char c = r & RX_FIFO_CHAR_MASK;
        consume(c);
        if (c == '$') {
            msgIndex = 0;
        }
        if (msgIndex < (sizeof(msgBuf) - 1)) {
            msgBuf[msgIndex++] = c;
        }
        if (c == '*') {
            msgBuf[msgIndex] = '\0';
            ret = msgBuf;
            msgIndex = 0;
        }
    }
    return ret;
}

int
ospreyGNSSEnableReception(int enable)
{
    if (!gnss.baseAddress) return -1;
    Xil_Out32(gnss.baseAddress+REG_IDX_CSR, enable ? CSR_W_ENABLE_RECEPTION
                                                   : CSR_W_DISABLE_RECEPTION);
    return 0;
}

int
ospreyGNSSStatus(void)
{
    if (!gnss.baseAddress) return -1;
    return Xil_In32(gnss.baseAddress+REG_IDX_CSR);
}

uint32_t
ospreyGNSSPPScount(void)
{
    if (!gnss.baseAddress) return -1;
    return Xil_In32(gnss.baseAddress+REG_IDX_PPS_COUNT);
}

uint32_t
ospreyGNSSStartGlitchCount(void)
{
    if (!gnss.baseAddress) return ~0UL;
    return Xil_In32(gnss.baseAddress+REG_IDX_START_GLITCH_COUNT);
}

uint32_t
ospreyGNSSFramingErrorCount(void)
{
    if (!gnss.baseAddress) return ~0UL;
    return Xil_In32(gnss.baseAddress+REG_IDX_START_GLITCH_COUNT);
}

uint32_t
ospreyGNSSOverrunCount(void)
{
    if (!gnss.baseAddress) return ~0UL;
    return Xil_In32(gnss.baseAddress+REG_IDX_OVERRUN_COUNT);
}

uint32_t
ospreyGNSSBadMessageCount(void)
{
    if (!gnss.baseAddress) return ~0UL;
    return Xil_In32(gnss.baseAddress+REG_IDX_BAD_MESSAGE_COUNT);
}

uint32_t
ospreyGNSSChecksumErrorCount(void)
{
    if (!gnss.baseAddress) return ~0UL;
    return Xil_In32(gnss.baseAddress+REG_IDX_CHECKSUM_ERROR_COUNT);
}

int
ospreyGNSSSendByte(int c)
{
    if (!gnss.baseAddress) return -1;
    if (ospreyGNSSStatus() & GNSS_STATUS_TRANSMITTER_BUSY) {
        return 1;
    }
    Xil_Out32(gnss.baseAddress+REG_IDX_RX_FIFO, c & 0xFF);
    return 0;
}
