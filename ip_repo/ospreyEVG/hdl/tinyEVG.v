// MIT License
//
// Copyright (c) 2024 Osprey DCS
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// Core of MRF-compatible event generator
// Provides heartbeats, time stamps, arbitrary events and distributed dbuf.

module tinyEVG #(
    parameter DISTRIBUTED_BUFFER_ADDRESS_WIDTH = 11,
    parameter SECONDS_WIDTH                    = 32,
    parameter DEBUG_DBUF                       = "false",
    parameter DEBUG                            = "false"
    ) (
    // Connection to transmitter
    input  wire                            evgTxClk,
    (*MARK_DEBUG=DEBUG*) output reg [15:0] evgTxWord = 0,
    (*MARK_DEBUG=DEBUG*) output reg  [1:0] evgTxIsK = 0,

    // Arbitrary event request
    input  wire               [7:0] eventCode,
    input  wire                     eventStrobe,

    // Heartbeat event request
    input  wire                     heartbeatRequest,

    // Time of day
    input  wire                     ppsStrobe,
    input  wire                     secondsStrobe,
    input  wire [SECONDS_WIDTH-1:0] seconds,

    // Distributed bus
    input  wire               [7:0] distributedBus,

    // Distributed buffer
    (*MARK_DEBUG=DEBUG_DBUF*)
    input  wire                                        dbufStart,
    (*MARK_DEBUG=DEBUG_DBUF*)
    output reg                                         dbufBusy = 0,
    (*MARK_DEBUG=DEBUG_DBUF*)
    input  wire [DISTRIBUTED_BUFFER_ADDRESS_WIDTH-1:0] dbufLastAddress,
    (*MARK_DEBUG=DEBUG_DBUF*)
    output reg  [DISTRIBUTED_BUFFER_ADDRESS_WIDTH-1:0] dbufAddress,
    (*MARK_DEBUG=DEBUG_DBUF*)
    input  wire                                  [7:0] dbufData);

/*
 * Space time-of-day events fairlyl widely so they
 * can be used as round-trip latency triggers.
 */
localparam SECONDS_GAP_COUNTER_WIDTH = 12;

localparam EVCODE_SHIFT_ZERO     = 8'h70;
localparam EVCODE_SHIFT_ONE      = 8'h71;
localparam EVCODE_HEARTBEAT      = 8'h7A;
localparam EVCODE_SECONDS_MARKER = 8'h7D;
localparam EVCODE_K28_0          = 8'h1C;
localparam EVCODE_K28_1          = 8'h3C;
localparam EVCODE_K28_5          = 8'hBC;

///////////////////////////////////////////////////////////////////////////////
// Event generator clock domain
(*MARK_DEBUG=DEBUG*) reg ppsPending = 0, haveSeconds = 0, sentSeconds = 0;
(*MARK_DEBUG=DEBUG*) reg [SECONDS_WIDTH-1:0] secondsReg, secondsShiftReg;
(*MARK_DEBUG=DEBUG*) reg [$clog2(SECONDS_WIDTH):0] secondsBitCount = ~0;
wire secondsBitCountDone = secondsBitCount[$clog2(SECONDS_WIDTH)];
reg secondsBitCountDone_d = 1;
(*MARK_DEBUG=DEBUG*) reg [SECONDS_GAP_COUNTER_WIDTH-1:0] secondsGap = 0;
wire secondsGapDone = secondsGap[SECONDS_GAP_COUNTER_WIDTH-1];
(*MARK_DEBUG=DEBUG*) reg [2:0] commaGap = 0;
wire commaGapDone = commaGap[2];

// Buffer transmission state machine
localparam S_START  = 3'd0,
           S_DATA   = 3'd1,
           S_STOP   = 3'd2,
           S_CHK_HI = 3'd3,
           S_CHK_LO = 3'd4;
(*MARK_DEBUG=DEBUG_DBUF*) reg [2:0] dbufState = S_START;
reg [15:0] dbufChecksum;

always @(posedge evgTxClk) begin
    // Timer housekeeping
    if (!secondsGapDone) secondsGap <= secondsGap + 1;
    commaGap <= commaGapDone ? 2 : commaGap - 1;

    // Update the time of day
    if (secondsStrobe) begin
        secondsReg <= seconds;
        haveSeconds <= 1;
    end

    // Make note of a PPS request
    if (ppsStrobe) begin
        if (!secondsStrobe) begin
            secondsReg <= secondsReg + 1;
        end
        if (!ppsPending) begin
            ppsPending <= 1;
        end
    end
    secondsBitCountDone_d <= secondsBitCountDone;
    if (secondsBitCountDone && !secondsBitCountDone_d) begin
        sentSeconds <= 1;
    end

    // Send events in priority order
    // Arbitrary event request
    if (eventStrobe) begin
        evgTxWord[15:8] <= eventCode;
        evgTxIsK[1] <= 0;
    end
    // Then heartbeats -- may be inhibited by arbitrary event but never delayed.
    else if (heartbeatRequest) begin
        evgTxWord[15:8] <= EVCODE_HEARTBEAT;
        evgTxIsK[1] <= 0;
    end
    // Then PPS markers (which could be delayed by an arbitrary amount).
    // Best practice is to ensure gap between arbitrary event requests to
    // minimize the PPS marker shift.
    else if (ppsPending) begin
        ppsPending <= 0;
        secondsGap <= 0;
        if (sentSeconds) begin
            evgTxWord[15:8] <= EVCODE_SECONDS_MARKER;
            evgTxIsK[1] <= 0;
        end
        else begin
            evgTxWord[15:8] <= 0;
            evgTxIsK[1] <= 0;
        end
        if (haveSeconds) begin
            secondsBitCount <= SECONDS_WIDTH - 1;
            secondsShiftReg <= secondsReg;
        end
    end
    // Lowest priorty -- POSIX seconds shift register
    else if (!secondsBitCountDone && secondsGapDone) begin
        secondsBitCount <= secondsBitCount - 1;
        secondsGap <= 0;
        secondsShiftReg <= { secondsShiftReg[0+:SECONDS_WIDTH-1], 1'b0 };
        evgTxWord[15:8] <= secondsShiftReg[SECONDS_WIDTH-1] ? EVCODE_SHIFT_ONE :
                                                             EVCODE_SHIFT_ZERO;
        evgTxIsK[1] <= 0;
    end
    else if (commaGapDone) begin
        evgTxWord[15:8] <= EVCODE_K28_5;
        evgTxIsK[1] <= 1;
    end
    else begin
        evgTxWord[15:8] <= 0;
        evgTxIsK[1] <= 0;
    end

    // Distributed data buffer
    if (dbufBusy) begin
        if (commaGap[0]) begin
            evgTxWord[7:0] <= distributedBus;
            evgTxIsK[0] <= 0;
        end
        else begin
            case (dbufState)
            S_START: begin
                evgTxWord[7:0] <= EVCODE_K28_0;
                evgTxIsK[0] <= 1;
                dbufState <= S_DATA;
            end
            S_DATA: begin
                evgTxWord[7:0] <= dbufData;
                evgTxIsK[0] <= 0;
                dbufChecksum <= dbufChecksum + dbufData;
                dbufAddress <= dbufAddress + 1;
                if (dbufAddress == dbufLastAddress) begin
                    dbufState <= S_STOP;
                end
            end
            S_STOP: begin
                dbufChecksum <= ~dbufChecksum;
                evgTxWord[7:0] <= EVCODE_K28_1;
                evgTxIsK[0] <= 1;
                dbufState <= S_CHK_HI;
            end
            S_CHK_HI: begin
                evgTxWord[7:0] <= dbufChecksum[15:8];
                evgTxIsK[0] <= 0;
                dbufState <= S_CHK_LO;
            end
            S_CHK_LO: begin
                evgTxWord[7:0] <= dbufChecksum[7:0];
                evgTxIsK[0] <= 0;
                dbufBusy <= 0;
            end
            default: ;
            endcase
        end
    end
    else begin
        evgTxWord[7:0] <= distributedBus;
        evgTxIsK[0] <= 0;
        dbufAddress <= 0;
        dbufChecksum <= 0;
        dbufState <= S_START;
        if (dbufStart) begin
            dbufBusy <= 1;
        end
    end
end

endmodule
