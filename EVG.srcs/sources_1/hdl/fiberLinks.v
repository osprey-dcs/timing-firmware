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
 * Application-specific MGT support
 */
`default_nettype none
module fiberLinks #(
    parameter MGT_COUNT        = -1,
    parameter MGT_DATA_WIDTH   = -1,
    parameter SYSCLK_RATE      = 100000000,
    parameter DEBUG            = "false"
    ) (
    input  wire        sysClk,
    input  wire        sysCsrStrobe,
    input  wire [31:0] sysGPIO_OUT,
    output wire [31:0] sysStatus,
    output wire [31:0] sysLinkStatus,

    input  wire                 gtRefClkP,
    input  wire                 gtRefClkN,
    output wire                 gtRefClkDiv2,
    input  wire [MGT_COUNT-1:0] rxP,
    input  wire [MGT_COUNT-1:0] rxN,
    output wire [MGT_COUNT-1:0] txP,
    output wire [MGT_COUNT-1:0] txN,

                         output wire        mgtTxClk,
    (*MARK_DEBUG=DEBUG*) input  wire [15:0] mgtTxChars,
    (*MARK_DEBUG=DEBUG*) input  wire  [1:0] mgtTxCharIsK,

                         output wire        evrClk,
    (*MARK_DEBUG=DEBUG*) output wire        evrLinkUp,
    (*MARK_DEBUG=DEBUG*) output wire [15:0] evrRxChars,
    (*MARK_DEBUG=DEBUG*) output wire  [1:0] evrRxCharIsK);


wire                      [MGT_COUNT-1:0] mgtRxClks;
wire                      [MGT_COUNT-1:0] mgtRxLinkUp;
wire     [(MGT_COUNT*MGT_DATA_WIDTH)-1:0] mgtRxChars;
wire [(MGT_COUNT*(MGT_DATA_WIDTH/8))-1:0] mgtRxCharIsK;

///////////////////////////////////////////////////////////////////////////////
// Pass EVR values up
assign evrClk       = mgtRxClks[0];
assign evrLinkUp    = mgtRxLinkUp[0];
assign evrRxChars   = mgtRxChars[15:0];
assign evrRxCharIsK = mgtRxCharIsK[1:0];

assign sysLinkStatus = { {32-MGT_COUNT{1'b0}}, mgtRxLinkUp };

//
// Instantiate the transceivers and support code
//
mgtWrapper #(
    .MGT_COUNT(MGT_COUNT),
    .MGT_DATA_WIDTH(16),
    .COMMA_ALIGN_BYTE(1),
    .SYSCLK_RATE(SYSCLK_RATE),
    .DEBUG(DEBUG))
  mgtWrapper_i (
    .sysClk(sysClk),
    .sysCsrStrobe(sysCsrStrobe),
    .sysGPIO_OUT(sysGPIO_OUT),
    .sysStatus(sysStatus),
    .gtRefClkP(gtRefClkP),
    .gtRefClkN(gtRefClkN),
    .gtRefClkDiv2(gtRefClkDiv2),
    .rxP(rxP),
    .rxN(rxN),
    .txP(txP),
    .txN(txN),
    .mgtRxClks(mgtRxClks),
    .mgtRxLinkUp(mgtRxLinkUp),
    .mgtRxChars(mgtRxChars),
    .mgtRxCharIsK(mgtRxCharIsK),
    .mgtTxClk(mgtTxClk),
    .mgtTxChars({MGT_COUNT{mgtTxChars}}),
    .mgtTxCharIsK({MGT_COUNT{mgtTxCharIsK}}));
endmodule

`default_nettype wire
