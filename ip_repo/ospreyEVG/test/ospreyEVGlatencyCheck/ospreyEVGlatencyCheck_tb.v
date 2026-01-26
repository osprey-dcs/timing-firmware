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
 * Test event system latency monitor
 */
`timescale 1ns/10ps

`default_nettype none
module ospreyEVGlatencyCheck_tb;

localparam N_PASSES         = 5;
localparam SAMPLES_PER_PASS = 1000;

localparam RX_COUNT        = 1;
localparam EVENT_CODE_BYTE = 1;
localparam MGT_DATA_WIDTH  = 16;
localparam DB_WIDTH        = 32;

localparam EVCODE_PPS  = 8'h7D;
localparam EVCODE_ZERO = 8'h70;
localparam EVCODE_ONE  = 8'h71;

reg                 sysClk = 0;
reg                 sysCsrStrobe = 0;
reg  [DB_WIDTH-1:0] sysGPIO_OUT = {DB_WIDTH{1'bx}};
wire [DB_WIDTH-1:0] sysStatus;

reg sampleClk = 0, sampleClkX4 = 0;

reg     [MGT_DATA_WIDTH-1:0] txChars = 0;
reg [(MGT_DATA_WIDTH/8)-1:0] txCharIsK = 0;

// Generate clocks
always begin #5 sysClk = !sysClk; end
always begin #4 sampleClk = !sampleClk; end
always begin #1 sampleClkX4 = !sampleClkX4; end

integer passIndex, sampleIndex;
reg txClkRaw = 0;
wire txClk;
wire [4:0] txClk_x = 0;
always begin
    #4 txClkRaw = !txClkRaw;
end
assign #0.7 txClk = txClkRaw;
assign #1.1 txClk_x[0] = txClkRaw;
assign #1.7 txClk_x[1] = txClkRaw;
assign #2.1 txClk_x[2] = txClkRaw;
assign #2.8 txClk_x[3] = txClkRaw;
assign #3.3 txClk_x[4] = txClkRaw;
wire rxClk = txClk_x[passIndex];

// Simulate link latency
reg [3:0] delayIndex = 0;
reg [(MGT_DATA_WIDTH/8)+MGT_DATA_WIDTH-1:0] delayBuf[0:15], delayBufQ;
always @(posedge txClk) begin
    delayIndex <= delayIndex + 1;
    delayBuf[delayIndex] <= {txCharIsK, txChars};
    delayBufQ <= delayBuf[delayIndex];
end
wire [(RX_COUNT*MGT_DATA_WIDTH)-1:0] rxChars;
wire [(RX_COUNT*(MGT_DATA_WIDTH/8))-1:0] rxCharIsK;
assign rxChars = {RX_COUNT{delayBufQ[0+:MGT_DATA_WIDTH]}};
assign rxCharIsK = {RX_COUNT{delayBufQ[MGT_DATA_WIDTH+:MGT_DATA_WIDTH/8]}};

// Instantiate device under test
ospreyEVGlatencyCheck #(
    .RX_COUNT(RX_COUNT),
    .EVENT_CODE_BYTE(EVENT_CODE_BYTE),
    .MGT_DATA_WIDTH(MGT_DATA_WIDTH))
  ospreyEVGlatencyCheck_i (
    .sysClk(sysClk),
    .sysCsrStrobe(sysCsrStrobe),
    .sysGPIO_OUT(sysGPIO_OUT),
    .sysStatus(sysStatus),
    .sampleClk(sampleClk),
    .sampleClkX4(sampleClkX4),
    .mgtRxClks({RX_COUNT{rxClk}}),
    .mgtRxChars(rxChars),
    .mgtRxCharIsK(rxCharIsK),
    .mgtTxClk(txClk),
    .mgtTxChars(txChars),
    .mgtTxCharIsK(txCharIsK));

///////////////////////////////////////////////////////////////////////////////
integer good = 1;
integer tickIndex = 0;
integer plotFile;
real latency;
initial
begin
    $dumpfile("ospreyEVGlatencyCheck_tb.fst");
    $dumpvars(0, ospreyEVGlatencyCheck_tb);
    plotFile = $fopen("ospreyEVGlatencyCheck_tb.dat", "w");

    #50;
    for (passIndex = 0 ; passIndex < N_PASSES ; passIndex = passIndex + 1) begin
        for (sampleIndex = 0 ; sampleIndex < SAMPLES_PER_PASS ;
                                            sampleIndex = sampleIndex + 1) begin
            sendEvent(EVCODE_PPS);
            #1000;
            latency = $itor(sysStatus >> 8) / 8.0;
            $fdisplay(plotFile, "%d %d %.2f", $time, tickIndex, latency);
            $write("%d %.2f", $time, latency);
            if (sampleIndex == (SAMPLES_PER_PASS - 1)) begin
                $display("     === %d", passIndex);
            end
            else begin
                $display("");
            end
            tickIndex <= tickIndex + 1;
        end
    end
    $fclose(plotFile);
    $finish;
end

// Transmit event code
task sendEvent;
    input [7:0] evCode;
    begin
    @(posedge txClk) txChars[EVENT_CODE_BYTE*8+:8] <= evCode;
    @(posedge txClk) txChars[EVENT_CODE_BYTE*8+:8] <= 0;
    end
endtask

// Write value to CSR
task writeCSR;
    input  [DB_WIDTH-1:0] value;
    begin
    @(posedge sysClk) begin
        sysGPIO_OUT <= value;
        sysCsrStrobe <= 1;
    end
    @(posedge sysClk) begin
        sysGPIO_OUT <= {DB_WIDTH{1'bx}};
        sysCsrStrobe <= 0;
    end
    @(posedge sysClk) ;
    end
endtask

endmodule
`default_nettype wire
