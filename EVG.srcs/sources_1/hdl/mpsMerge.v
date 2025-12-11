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
 * Merge fault status from multiple receivers.
 */
`default_nettype none
module mpsMerge #(
    parameter MGT_COUNT          = 8,
    parameter MGT_DATA_WIDTH     = 16,
    parameter MPS_OUTPUT_COUNT   = 8,
    parameter BASE_MERGE_MGT_IDX = 2,
    parameter EVCODE_BYTE        = 1,
    parameter DEBUG              = "false"
    ) (
    input  wire        sysClk,
    input  wire        sysCsrStrobe,
    input  wire [31:0] sysGPIO_OUT,
    output wire [31:0] sysStatus,

    (*MARK_DEBUG=DEBUG*)input wire [(MGT_COUNT*MGT_DATA_WIDTH)-1:0] mgtRxChars,
    (*MARK_DEBUG=DEBUG*)input wire                  [MGT_COUNT-1:0] mgtRxLinkUp,

    (*MARK_DEBUG=DEBUG*) output wire [MPS_OUTPUT_COUNT-1:0] mpsMergedFaults_a);

localparam MUX_SEL_WIDTH = $clog2(MGT_COUNT);
localparam DBUS_BASE_BIT = (1 - EVCODE_BYTE) * 8;

///////////////////////////////////////////////////////////////////////////////
// System clock domain
(*MARK_DEBUG=DEBUG*) reg [MGT_COUNT-1:0] linkImportant = {MGT_COUNT{1'b1}};
reg [MUX_SEL_WIDTH-1:0] muxSel = 0;
(*ASYNC_REG="true"*) reg [MGT_DATA_WIDTH-1:0] faultMux;

always @(posedge sysClk) begin
    if (sysCsrStrobe) begin
        if (sysGPIO_OUT[31]) begin
            linkImportant <= sysGPIO_OUT[MGT_COUNT-1];
        end
        else begin
            muxSel <= sysGPIO_OUT[MUX_SEL_WIDTH-1];
        end
    end
    faultMux <= 
          mgtRxChars[((muxSel*MGT_DATA_WIDTH)+DBUS_BASE_BIT)+:MPS_OUTPUT_COUNT];
end
assign sysStatus = { {8-MPS_OUTPUT_COUNT{1'b0}}, mpsMergedFaults_a,
                     {8-MPS_OUTPUT_COUNT{1'b0}}, faultMux,
                     {16-MGT_COUNT{1'b0}}, linkImportant };

///////////////////////////////////////////////////////////////////////////////
// Merge fault status from all incoming fiber links.

/*
 * Merging is done combinatorially since any race condition
 * will be resolved on the next transmitter clock cycle.
 *
 * "To iterate is human, to recurse, divine." -- Attributed to L Peter Deutsch
 */
function [MPS_OUTPUT_COUNT-1:0] merge;
    input            [MPS_OUTPUT_COUNT-1:0] linkImportant;
    input                   [MGT_COUNT-1:0] mgtRxLinkUp;
    input  [(MGT_COUNT*MGT_DATA_WIDTH)-1:0] mgtRxChars;
    input                           integer i;
    merge = (i < BASE_MERGE_MGT_IDX) ? 0 :
           (({MPS_OUTPUT_COUNT{linkImportant[i]}} &
             (mgtRxChars[((i*MGT_DATA_WIDTH)+DBUS_BASE_BIT)+:MPS_OUTPUT_COUNT] |
             {MPS_OUTPUT_COUNT{!mgtRxLinkUp[i]}})) |
                            merge(linkImportant, mgtRxLinkUp, mgtRxChars, i-1));
endfunction

assign mpsMergedFaults_a =
                     merge(linkImportant, mgtRxLinkUp, mgtRxChars, MGT_COUNT-1);
endmodule
`default_nettype wire
