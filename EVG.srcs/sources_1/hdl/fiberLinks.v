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
 * Instantiate all multi-gigabit transceivers and the code associated with them.
 *      evrXXXX   -- Event receiver in
 *      evfXXXX   -- Event fanout out
 *      evsXXXX   -- Event source (generator or fanout) out
 *
 * Fibers:
 *  1 (QSFP1-1)
 *          Input -- Event receiver
 *          Output -- High byte event code loopback
 *          Output -- Low byte MPS faults
 *
 *  2-8 (QSFP1-2:4, QSFP2-1:4)
 *          Input -- Latency measurement event codes and MPS faults
 *          Output -- Event/data streams
 *                            Source is event generator on EVG node.
 *                            Source is event fanout from other nodes.
 */
`default_nettype none
module fiberLinks #(
    parameter MGT_COUNT          = 8,
    parameter MGT_DATA_WIDTH     = 16,
    parameter MGT_CTYPE_WIDTH     = (MGT_DATA_WIDTH + 7) / 8,
    parameter MPS_OUTPUT_COUNT   = 8,
    parameter DEBUG_MGT          = "false",
    parameter DEBUG_EVR          = "false",
    parameter DEBUG_EVF          = "false",
    parameter DEBUG_EVG          = "false",
    parameter DEBUG_EVS          = "false",
    parameter DEBUG_MPS          = "false",
    parameter DEBUG              = "false"
    ) (
                         input  wire                       sysClk,
    (*MARK_DEBUG=DEBUG*) input  wire                       sysMgtCsrStrobe,
    (*MARK_DEBUG=DEBUG*) input  wire                [31:0] sysGPIO_OUT,
    (*MARK_DEBUG=DEBUG*) output wire                [31:0] sysMgtStatus,
    (*MARK_DEBUG=DEBUG*) output wire                [31:0] sysLinkStatus,
                         input  wire                       isEVG,

    output wire                   [MGT_COUNT-1:0] mgtRxClks,
    output wire                   [MGT_COUNT-1:0] mgtRxLinkUp,
    output wire  [(MGT_COUNT*MGT_DATA_WIDTH)-1:0] mgtRxChars,
    output wire [(MGT_COUNT*MGT_CTYPE_WIDTH)-1:0] mgtRxCharIsK,

    output wire                        mgtTxClk,
    input  wire [MPS_OUTPUT_COUNT-1:0] mgtTxMPStripped,
    input  wire   [MGT_DATA_WIDTH-1:0] evgTxChars,
    input  wire  [MGT_CTYPE_WIDTH-1:0] evgTxCharIsK,

    input  wire                 gtRefClk,
    input  wire [MGT_COUNT-1:0] rxP,
    input  wire [MGT_COUNT-1:0] rxN,
    output wire [MGT_COUNT-1:0] txP,
    output wire [MGT_COUNT-1:0] txN);

// Lots of different clock domains, but races unimportant
assign sysLinkStatus = { {32-MGT_COUNT{1'b0}}, mgtRxLinkUp};

///////////////////////////////////////////////////////////////////////////////
// Select event source and set up transmit values
(*ASYNC_REG="true"*) reg mgtIsEVG_m;
                     reg mgtIsEVG;
wire  [MGT_DATA_WIDTH-1:0] evfTxChars;
wire [MGT_CTYPE_WIDTH-1:0] evfTxCharIsK;

always @(posedge mgtTxClk) begin
    mgtIsEVG_m <= isEVG;
    mgtIsEVG   <= mgtIsEVG_m;
end

(*MARK_DEBUG=DEBUG_EVS*) wire  [MGT_DATA_WIDTH-1:0] evsTxChars =
                                        mgtIsEVG ? evgTxChars   : evfTxChars;
(*MARK_DEBUG=DEBUG_EVS*) wire [MGT_CTYPE_WIDTH-1:0] evsTxCharIsK =
                                        mgtIsEVG ? evgTxCharIsK : evfTxCharIsK;

wire [(MGT_COUNT*MGT_DATA_WIDTH)-1:0] mgtTxChars = {
                                    {MGT_COUNT-1{evsTxChars}},
                                    evsTxChars[15:8],
                                    {8-MPS_OUTPUT_COUNT{1'b0}}, mgtTxMPStripped};
wire [(MGT_COUNT*MGT_CTYPE_WIDTH)-1:0] mgtTxCharIsK = {
                            {MGT_COUNT-1{evsTxCharIsK}}, evsTxCharIsK[1], 1'b0};

///////////////////////////////////////////////////////////////////////////////

// Instantiate the multi gigabit transceivers
mgtWrapper #(
    .MGT_COUNT(MGT_COUNT),
    .MGT_DATA_WIDTH(MGT_DATA_WIDTH),
    .COMMA_ALIGN_BYTE(1),
    .DEBUG(DEBUG_MGT))
mgtWrapper_i (
    .sysClk(sysClk),
    .sysCsrStrobe(sysMgtCsrStrobe),
    .sysGPIO_OUT(sysGPIO_OUT),
    .sysStatus(sysMgtStatus),
    .gtRefClk(gtRefClk),
    .rxP(rxP),
    .rxN(rxN),
    .txP(txP),
    .txN(txN),
    .mgtRxClks(mgtRxClks),
    .mgtRxLinkUp(mgtRxLinkUp),
    .mgtRxChars(mgtRxChars),
    .mgtRxCharIsK(mgtRxCharIsK),
    .mgtTxClk(mgtTxClk),
    .mgtTxChars(mgtTxChars),
    .mgtTxCharIsK(mgtTxCharIsK));

// Minimal event fanout
evf #(
    .DATA_WIDTH(MGT_DATA_WIDTH),
    .CTYPE_WIDTH(MGT_CTYPE_WIDTH),
    .DEBUG(DEBUG_EVF))
  evf_i (
    .rxClk(mgtRxClks[0]),
    .rxLinkUp(mgtRxLinkUp[0]),
    .rxChars(mgtRxChars[MGT_DATA_WIDTH-1:0]),
    .rxCharIsK(mgtRxCharIsK[MGT_CTYPE_WIDTH-1:0]),
    .txClk(mgtTxClk),
    .txChars(evfTxChars),
    .txCharIsK(evfTxCharIsK));

endmodule
`default_nettype wire
