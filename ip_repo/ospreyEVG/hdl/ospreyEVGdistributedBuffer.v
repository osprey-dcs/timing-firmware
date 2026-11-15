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
 * Distributed Buffer(s)
 */
`timescale  1 ns / 1 ns
`default_nettype none
module ospreyEVGdistributedBuffer #(
    parameter DB_ADDR_WIDTH = 11,
    parameter DB_COUNT      = 2,
    parameter DEBUG         = "false"
    ) (
    input  wire        sysClk,
    input  wire        sysCsrStrobe,
    input  wire        sysWriteEnable,
    input  wire [31:0] sysWriteData,
    input  wire  [3:0] sysByteEnable,
    output wire [31:0] sysStatus,
    output wire [31:0] sysReadData,

    input  wire                        evgClk,
    input  wire      [TIMER_COUNT-1:0] evgTimerTrigger,
    input  wire [HW_TRIGGER_COUNT-1:0] evgHwTriggerRising,
    input  wire [HW_TRIGGER_COUNT-1:0] evgHwTriggerFalling,
    output reg      [EVCODE_WIDTH-1:0] evgCodeTDATA = 0,
    output reg                         evgCodeTVALID = 0);

endmodule
`default_nettype wire
