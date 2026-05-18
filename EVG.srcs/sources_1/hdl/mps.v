/*
 * MIT License
 *
 * Copyright (c) 2026 Osprey DCS
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
 * MPS operations
 */
`default_nettype none
module mps #(
    parameter [7:0] EVR_MPS_CLEAR_EVENT = 255,
    parameter MGT_COUNT                 = -1,
    parameter MGT_DATA_WIDTH            = -1,
    parameter MGT_CTYPE_WIDTH           = -1,
    parameter MPS_INPUT_COUNT           = -1,
    parameter MPS_OUTPUT_COUNT          = -1,
    parameter TIMESTAMP_WIDTH           = -1,
    parameter DEBUG                     = "false"
    ) (
    input  wire        sysClk,
    input  wire        sysLocalCsrStrobe,
    input  wire        sysLocalDataStrobe,
    input  wire        sysMergeCsrStrobe,
    input  wire [31:0] sysGPIO_OUT,
    output wire [31:0] sysLocalStatus,
    output wire [31:0] sysLocalData,
    output wire [31:0] sysMergeStatus,

    input wire                   [MGT_COUNT-1:0] mgtRxClks,
    input wire  [(MGT_COUNT*MGT_DATA_WIDTH)-1:0] mgtRxChars,
    input wire [(MGT_COUNT*MGT_CTYPE_WIDTH)-1:0] mgtRxCharIsK,
    input wire                   [MGT_COUNT-1:0] mgtRxLinkUp,
    input wire             [TIMESTAMP_WIDTH-1:0] evrTimestamp,

    input  wire [MPS_INPUT_COUNT-1:0] mpsInputStates_a,

    input  wire                 mgtTxClk,
    output reg  [MGT_COUNT-1:0] mpsTripped);

///////////////////////////////////////////////////////////////////////////////
// Detect "MPS Clear" events
// FIXME: Should the 'MPS Clear' event be a run-time selection?
reg evrClearMPS = 0;
always @(posedge mgtRxClks[0]) begin
    if (!mgtRxCharIsK[1] && (mgtRxChars[15:8] == EVR_MPS_CLEAR_EVENT)) begin
        evrClearMPS <= 1;
    end
    else begin
        evrClearMPS <= 0;
    end
end

///////////////////////////////////////////////////////////////////////////////
// Send combined MPS trips

wire [MPS_OUTPUT_COUNT-1:0] mpsLocalTripped, mpsRemoteTripped;
always @(posedge mgtTxClk) begin
    mpsTripped <= mpsLocalTripped | mpsRemoteTripped;
end

///////////////////////////////////////////////////////////////////////////////
// Generate local MPS trips
mpsLocal #(
    .MPS_OUTPUT_COUNT(MPS_OUTPUT_COUNT),
    .MPS_INPUT_COUNT(MPS_INPUT_COUNT),
    .TIMESTAMP_WIDTH(TIMESTAMP_WIDTH),
    .DEBUG(DEBUG))
  mpsLocal_i (
    .sysClk(sysClk),
    .sysCsrStrobe(sysLocalCsrStrobe),
    .sysDataStrobe(sysLocalDataStrobe),
    .sysGPIO_OUT(sysGPIO_OUT),
    .sysStatus(sysLocalStatus),
    .sysData(sysLocalData),
    .acqClk(mgtRxClks[0]),
    .acqClearTrip(evrClearMPS),
    .acqTimestamp(evrTimestamp),
    .mpsInputStates_a(mpsInputStates_a),
    .mgtTxClk(mgtTxClk),
    .mpsTripped(mpsLocalTripped));

///////////////////////////////////////////////////////////////////////////////
// Receive MPS trips from downstreamm nodes
mpsMerge #(
    .MGT_COUNT(MGT_COUNT),
    .MGT_DATA_WIDTH(MGT_DATA_WIDTH),
    .MPS_OUTPUT_COUNT(MPS_OUTPUT_COUNT),
    .DEBUG(DEBUG))
  mpsMerge_i (
    .sysClk(sysClk),
    .sysCsrStrobe(sysMergeCsrStrobe),
    .sysGPIO_OUT(sysGPIO_OUT),
    .sysStatus(sysMergeStatus),
    .evrClear(evrClearMPS),
    .mgtRxChars(mgtRxChars),
    .mgtRxLinkUp(mgtRxLinkUp),
    .mgtTxClk(mgtTxClk),
    .mpsTripped(mpsRemoteTripped));

endmodule
`default_nettype wire
