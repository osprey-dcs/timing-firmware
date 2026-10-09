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

module ospreyTRGOUT(
    input  wire        sysClk,
    input  wire  [1:0] jtrStrobe,
    input  wire [31:0] GPIO_OUT,
    output wire [31:0] jtrData1,
    output wire [31:0] jtrData2,

    input wire         sysFMCisPresent,
    output wire  [1:0] Cleaner_LevelShift_OEn,
    output wire  [1:0] Cleaner_ClkBuffer_OEn,
    output wire  [1:0] Cleaner_RSTn,
    output wire  [1:0] Cleaner_SPI_CLK,
    output wire  [1:0] Cleaner_SPI_SDI, // MOSI
    output wire  [1:0] Cleaner_SPI_CSn,
    input wire   [1:0] Cleaner_SPI_SDO, // MISO
    input wire   [1:0] Cleaner_Fault_INTR,
    input wire   [1:0] Cleaner_Fault_LOS_XO,
    input wire   [1:0] Cleaner_Fault_LOL
);
genvar i;

wire [31:0] GPIO_IN [1:0];
assign jtrData1 = GPIO_IN[0];
assign jtrData2 = GPIO_IN[1];

generate
    for (i = 0 ; i < 2 ; i = i + 1) begin : perFMC2Bank
    reg [5:0] outbank_l = 6'b111000; // outputs disabled, and (invert) reset asserted

    assign Cleaner_LevelShift_OEn[i] = sysFMCisPresent ? outbank_l[5] : 1'bz;
    assign Cleaner_ClkBuffer_OEn[i] = sysFMCisPresent ? outbank_l[4] : 1'bz;
    assign Cleaner_RSTn[i] = sysFMCisPresent ? ~outbank_l[3] : 1'bz; // invert
    assign Cleaner_SPI_CSn[i] = sysFMCisPresent ? outbank_l[2] : 1'bz;
    assign Cleaner_SPI_CLK[i] = sysFMCisPresent ? outbank_l[1] : 1'bz;
    assign Cleaner_SPI_SDI[i] = sysFMCisPresent ? outbank_l[0] : 1'bz;

    assign GPIO_IN[i] = {
        sysFMCisPresent,
        19'h0,
        Cleaner_Fault_LOL[i],
        Cleaner_Fault_LOS_XO[i],
        Cleaner_Fault_INTR[i],
        Cleaner_SPI_SDO[i],
        2'h0,
        outbank_l
    };
    always @(posedge sysClk) begin
        if(jtrStrobe[i]) begin
          outbank_l <= GPIO_OUT[5:0];
        end
    end
end
endgenerate

endmodule
