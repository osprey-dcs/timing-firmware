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
 * Select I/O assignments
 */
`default_nettype none
module ioSelect #(
    parameter EVG_HW_INPUT_COUNT  = 16,
    parameter EVR_HW_OUTPUT_COUNT = 8,
    parameter FMC_INPUT_COUNT     = 16,
    parameter PMOD_INPUT_COUNT    = 8,
    parameter DEBUG               = "false"
    ) (
    input  wire        sysClk,
    input  wire        sysCsrStrobe,
    input  wire [31:0] sysGPIO_OUT,
    output wire [31:0] sysStatus,

    output wire  [EVG_HW_INPUT_COUNT-1:0] evgHwInputs,

    input  wire   [FMC_INPUT_COUNT-1:0] fmcInputs,
    input  wire  [PMOD_INPUT_COUNT-1:0] pmodInputs);

///////////////////////////////////////////////////////////////////////////////
// System clock domain
reg sysIsEVG = 0;
reg sysFMCisPresent = 0;
reg sysPMOD1IsIO = 0;
reg sysPMOD1IsGPS = 0;

always @(posedge sysClk) begin
    if (sysCsrStrobe) begin
        if (sysGPIO_OUT[8])  sysIsEVG        <= sysGPIO_OUT[0];
        if (sysGPIO_OUT[9])  sysFMCisPresent <= sysGPIO_OUT[1];
        if (sysGPIO_OUT[10]) sysPMOD1IsIO    <= sysGPIO_OUT[2];
        if (sysGPIO_OUT[11]) sysPMOD1IsGPS   <= sysGPIO_OUT[3];
    end
end

assign sysStatus = { {32-4{1'b0}},
                     sysPMOD1IsGPS, sysPMOD1IsIO, sysFMCisPresent, sysIsEVG };

genvar i;
generate

for (i = 0 ; i < EVG_HW_INPUT_COUNT ; i = i + 1) begin : evgHwIn
    assign evgHwInputs[i] = sysFMCisPresent ? fmcInputs[i] :
                            (i < PMOD_INPUT_COUNT) ? pmodInputs[i] :
                            1'b0;
end

endgenerate
endmodule
`default_nettype wire
