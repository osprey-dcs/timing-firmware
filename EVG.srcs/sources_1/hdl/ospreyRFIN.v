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
 * Bit-bang interface to control Osprey RF-IN FMC module devices.
 * Firmware readout of input level monitoring ADCs.
 */
`default_nettype none
module ospreyRFIN #(
    parameter SYSCLK_RATE = 100000000,
    parameter ADCCLK_RATE = 1000000,
    parameter DEBUG       = "false"
    ) (
    input  wire        sysClk,
    input  wire        csrStrobe,
    input  wire [31:0] GPIO_OUT,
    output reg  [31:0] readback = 0,

    (*MARK_DEBUG=DEBUG*) output reg  RFIN_LMK01801_CLK = 0,
    (*MARK_DEBUG=DEBUG*) output reg  RFIN_LMK01801_LE = 0,
    (*MARK_DEBUG=DEBUG*) output reg  RFIN_LMK01801_DATA = 0,

    (*MARK_DEBUG=DEBUG*) output reg  RFIN_ADS7253_CLK = 0,
    (*MARK_DEBUG=DEBUG*) output reg  RFIN_ADS7253_CSB = 1,
    (*MARK_DEBUG=DEBUG*) output reg  RFIN_ADS7253_DIN = 0,
    (*MARK_DEBUG=DEBUG*) input  wire RFIN_ADS7253_DOUTA,
    (*MARK_DEBUG=DEBUG*) input  wire RFIN_ADS7253_DOUTB);

localparam TICK_DIVISOR = ((SYSCLK_RATE/2) + ADCCLK_RATE - 1) / ADCCLK_RATE;
localparam TICK_COUNTER_LOAD = TICK_DIVISOR - 2;
localparam TICK_COUNTER_WIDTH = $clog2(TICK_COUNTER_LOAD+1) + 1;

localparam BIT_COUNTER_LOAD = 32 - 2;
localparam BIT_COUNTER_WIDTH = $clog2(BIT_COUNTER_LOAD+1) + 1;

reg [TICK_COUNTER_WIDTH-1:0] tickCounter = TICK_COUNTER_LOAD;
(*MARK_DEBUG=DEBUG*) wire tick = tickCounter[TICK_COUNTER_WIDTH-1];

reg [BIT_COUNTER_WIDTH-1:0] bitCounter = BIT_COUNTER_LOAD;
(*MARK_DEBUG=DEBUG*) wire bitCounterDone = bitCounter[BIT_COUNTER_WIDTH-1];

reg [15:0] shiftA = 0, shiftB = 0;

(*MARK_DEBUG=DEBUG*) reg adcStop = 0, adcStart = 0, adcStopped = 0;
reg sysADCclk = 0, sysADCcsb = 1, sysADCdin = 0;

always @(posedge sysClk) begin
    if (csrStrobe) begin
        RFIN_LMK01801_DATA <=  GPIO_OUT[7];
        RFIN_LMK01801_LE   <=  GPIO_OUT[6];
        RFIN_LMK01801_CLK  <=  GPIO_OUT[5];
        sysADCdin          <=  GPIO_OUT[4];
        sysADCcsb          <= !GPIO_OUT[3];
        sysADCclk          <=  GPIO_OUT[2];
        adcStart           <=  GPIO_OUT[1];
        adcStop            <=  GPIO_OUT[0];
    end

    /*
     * ADC clock timing
     */
    if (tick) begin
        tickCounter <= TICK_COUNTER_LOAD;
    end
    else begin
        tickCounter <= tickCounter - 1;
    end

    /*
     * ADC control/readout
     */
    if (adcStopped) begin
        if (adcStart) begin
            adcStopped <= 0;
        end
        RFIN_ADS7253_CLK <= sysADCclk;
        RFIN_ADS7253_CSB <= sysADCcsb;
        RFIN_ADS7253_DIN <= sysADCdin;
        readback <= {{29{1'b0}}, RFIN_ADS7253_DOUTB, RFIN_ADS7253_DOUTA, 1'b1};
    end
    else if (tick) begin
        RFIN_ADS7253_CLK <= !RFIN_ADS7253_CLK;
        RFIN_ADS7253_DIN <= 0;
        if (RFIN_ADS7253_CSB) begin
            bitCounter <= BIT_COUNTER_LOAD;
            if (adcStop) begin
                adcStopped <= 1;
            end
            else if (!RFIN_ADS7253_CLK) begin
                RFIN_ADS7253_CSB <= 0;
            end
        end
        else begin
            if (RFIN_ADS7253_CLK) begin
                shiftA <= {shiftA[14:0], RFIN_ADS7253_DOUTA};
                shiftB <= {shiftB[14:0], RFIN_ADS7253_DOUTB};
            end
            else begin
                bitCounter <= bitCounter - 1;
                if (bitCounterDone) begin
                    RFIN_ADS7253_CSB <= 1;
                    readback <= {shiftB, shiftA[15:1], 1'b0};
                end
            end
        end
    end
end

endmodule
`default_nettype wire
