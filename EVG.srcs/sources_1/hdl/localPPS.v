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
 * Generate local PPS marker from 20 MHz VCXO (Y3) or system clock.
 */
`default_nettype none
module localPPS #(
    parameter SYSCLK_RATE = 100000000,
    parameter DEBUG       = "false"
    ) (
    input  wire        sysClk,
    input  wire        sysCsrStrobe,
    input  wire [31:0] sysGPIO_OUT,
    output wire [31:0] sysStatus,

    input  wire clk20,
    output wire localPPSmarker);

reg sysEnableLocal = 0;
reg sysEnableClk20 = 0;
wire ppsClk20, ppsSys;

always @(posedge sysClk) begin
    if (sysCsrStrobe) begin
        sysEnableLocal <= sysGPIO_OUT[0];
        sysEnableClk20 <= sysGPIO_OUT[1] & !sysGPIO_OUT[0];
    end
end
assign sysStatus = { {30{1'b0}}, sysEnableClk20, sysEnableLocal };

localPPSsrc #(
    .CLK_RATE(SYSCLK_RATE))
  localPPSsrc_sys (
    .clk(sysClk),
    .enable_a(sysEnableLocal),
    .pps(ppsSys));

localPPSsrc #(
    .CLK_RATE(20000000))
  localPPSsrc_clk20 (
    .clk(clk20),
    .enable_a(sysEnableClk20),
    .pps(ppsClk20));

assign localPPSmarker = ppsClk20 | ppsSys;

endmodule

module localPPSsrc #(
    parameter CLK_RATE = -1,
    parameter DEBUG    = "false") (
    input  wire clk,
    input  wire enable_a,
    output wire pps);

localparam COUNTER_RELOAD = CLK_RATE - 2;
localparam COUNTER_WIDTH = $clog2(COUNTER_RELOAD+1) + 1;
reg [COUNTER_WIDTH-1:0] counter = COUNTER_RELOAD;
wire counterDone = counter[COUNTER_WIDTH-1];

(*ASYNC_REG=DEBUG*) reg enable_m = 0;
(*MARK_DEBUG=DEBUG*) reg enable = 0;
(*MARK_DEBUG=DEBUG*) reg [3:0] ppsStretch = 0;
assign pps = ppsStretch[3];
always @(posedge clk) begin
    enable_m <= enable_a;
    enable   <= enable_m;
    if (counterDone || !enable) begin
        counter <= COUNTER_RELOAD;
    end
    else begin
        counter <= counter - 1;
    end
    if (pps) begin
        ppsStretch <= ppsStretch - 1;
    end
    else if (counterDone && enable) begin
        ppsStretch <= ~0;
    end
end
endmodule
`default_nettype wire
