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
 * Bit-bang interface to RF-IN FMC module
 */
`default_nettype none
module ospreyRFIN #(
    parameter DEBUG = "false"
    ) (
    input  wire        sysClk,
    input  wire        csrStrobe,
    input  wire [31:0] GPIO_OUT,
    output wire [31:0] status,

    output wire RFIN_LMK01801_LE,
    output wire RFIN_LMK01801_CLK,
    output wire RFIN_LMK01801_DATA,

    output wire RFIN_ADS7253_CLK,
    output wire RFIN_ADS7253_CSB,
    output wire RFIN_ADS7253_DIN,
    input  wire RFIN_ADS7253_DOUTA,
    input  wire RFIN_ADS7253_DOUTB);

(*MARK_DEBUG=DEBUG*) reg [5:0] fmcBits = 0;

always @(posedge sysClk) begin
    if (csrStrobe) fmcBits <= GPIO_OUT[5:0];
end

assign RFIN_ADS7253_CLK   =  fmcBits[0];
assign RFIN_ADS7253_CSB   = !fmcBits[1];
assign RFIN_ADS7253_DIN   =  fmcBits[2];
assign RFIN_LMK01801_CLK  =  fmcBits[3]; 
assign RFIN_LMK01801_LE   =  fmcBits[4]; 
assign RFIN_LMK01801_DATA =  fmcBits[5]; 

assign status = { {30{1'b0}}, RFIN_ADS7253_DOUTB, RFIN_ADS7253_DOUTA };
endmodule
`default_nettype wire
