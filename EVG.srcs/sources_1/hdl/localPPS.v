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
 * Generate local PPS marker from 20 MHz VCXO (Y3)
 */
`default_nettype none
module localPPS #(
    parameter DEBUG = "false"
    ) (
    input  wire        sysClk,
    input  wire        sysCsrStrobe,
    input  wire [31:0] sysGPIO_OUT,
    output wire [31:0] sysStatus,

    input  wire clk20,
    output wire localPPSmarker);

localparam VCXO_RATE = 20000000;

reg sysEnable = 0;

always @(posedge sysClk) begin
    if (sysCsrStrobe) begin
        sysEnable <= sysGPIO_OUT[0];
    end
end
assign sysStatus = { {31{1'b0}}, sysEnable };

localparam COUNTER_RELOAD = VCXO_RATE - 2;
localparam COUNTER_WIDTH = $clog2(COUNTER_RELOAD+1) + 1;
reg [COUNTER_WIDTH-1:0] counter = COUNTER_RELOAD;
wire counterDone = counter[COUNTER_WIDTH-1];

(*ASYNC_REG=DEBUG*) reg enable_m = 0;
(*MARK_DEBUG=DEBUG*) reg enable = 0;
(*MARK_DEBUG=DEBUG*) reg [3:0] ppsStretch = 0;
assign localPPSmarker = ppsStretch[3];

always @(posedge clk20) begin
    enable_m <= sysEnable;
    enable   <= enable_m;
    if (counterDone) begin
        counter <= COUNTER_RELOAD;
    end
    else begin
        counter <= counter - 1;
    end

    if (localPPSmarker) begin
        ppsStretch <= ppsStretch - 1;
    end
    else if (enable) begin
        if (counterDone) begin
            ppsStretch <= ~0;
        end
    end
end
endmodule
`default_nettype wire
