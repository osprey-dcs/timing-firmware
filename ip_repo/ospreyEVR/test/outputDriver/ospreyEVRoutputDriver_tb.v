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
 * Test event receiver output driver module
 */
`timescale 1ns/100ps

`default_nettype none
module ospreyEVRoutputDriver_tb;

parameter  SERDES_FACTOR = 1;
localparam DATA_WIDTH    = 32;

reg sysClk = 0, evrClk = 0, evrBitClk = 0;

reg sysControlUpdateToggle = 0,
    sysDelayCountUpdateToggle = 0,
    sysWidthCountUpdateToggle = 0;
reg [DATA_WIDTH-1:0] sysControlUpdateData = 0,
                     sysDelayCountUpdateData = 0,
                     sysWidthCountUpdateData = 0;


reg evrResetSERDES = 0,
    evrActionIn = 0,
    evrDbusIn = 0,
    evrSetIn = 0,
    evrResetIn = 0,
    extIn_a = 0;

wire evrDriverOut;

// Generate clocks
always begin #5 sysClk = !sysClk; end
always begin #4 evrClk = !evrClk; end
always begin #1 evrBitClk = !evrBitClk; end

ospreyEVRoutputDriver #(
    .DATA_WIDTH(DATA_WIDTH),
    .SERDES_FACTOR(SERDES_FACTOR))
  ospreyEVRoutputDriver_i (
    .sysControlUpdateToggle(sysControlUpdateToggle),
    .sysDelayCountUpdateToggle(sysDelayCountUpdateToggle),
    .sysWidthCountUpdateToggle(sysWidthCountUpdateToggle),
    .sysControlUpdateData(sysControlUpdateData),
    .sysDelayCountUpdateData(sysDelayCountUpdateData),
    .sysWidthCountUpdateData(sysWidthCountUpdateData),
    .evrClk(evrClk),
    .evrBitClk(evrBitClk),
    .evrResetSERDES(evrResetSERDES),
    .evrActionIn(evrActionIn),
    .evrDbusIn(evrDbusIn),
    .evrSetIn(evrSetIn),
    .evrResetIn(evrResetIn),
    .extIn_a(extIn_a),
    .evrDriverOut(evrDriverOut));


///////////////////////////////////////////////////////////////////////////////
realtime Tref, Tdiff;
always @(posedge evrActionIn) begin
    Tref = $time;
end
always @(posedge evrDriverOut) begin
    Tdiff = $time - Tref;
    Tref = $time;
    $write("Delay: %.2f  ", Tdiff);
end
always @(negedge evrDriverOut) begin
    Tdiff = $time - Tref;
    $display("Width: %.2f", Tdiff);
end



///////////////////////////////////////////////////////////////////////////////
integer good = 1;
initial
begin
    $dumpfile("ospreyEVRoutputDriver_tb.fst");
    $dumpvars(0, ospreyEVRoutputDriver_tb);

    #50;
    configPulse(8'hF0, 8'h03, 1, 1);
    emitPulse();
    configPulse(8'hFF, 8'hFF, 0, 1);
    emitPulse();
    configPulse(8'hFF, 8'hFF, 0, 0);
    emitPulse();
    $finish;
end

task configPulse;
    input [7:0] firstWord;
    input [7:0] lastWord;
    input [31:0] delayCount;
    input [31:0] widthCount;
    begin
    @(posedge sysClk) begin
        sysControlUpdateData <= {16'h0001, lastWord, firstWord};
        sysControlUpdateToggle <= !sysControlUpdateToggle;
    end
    @(posedge sysClk) begin
        sysDelayCountUpdateData <= delayCount;
        sysDelayCountUpdateToggle <= !sysDelayCountUpdateToggle;
    end
    @(posedge sysClk) begin
        sysWidthCountUpdateData <= widthCount;
        sysWidthCountUpdateToggle <= !sysWidthCountUpdateToggle;
    end
    #100;
    end
endtask

task emitPulse;
    begin
    @(posedge evrClk) begin evrActionIn <= 1'b1; end
    @(posedge evrClk) begin evrActionIn <= 1'b0; end
    #100;
    end
endtask

endmodule


module B_OSERDESE2 #(
    parameter DATA_RATE_OQ = 0,
    parameter DATA_RATE_TQ = 0,
    parameter DATA_WIDTH = 8,
    parameter INIT_OQ = 0,
    parameter INIT_TQ = 0,
    parameter SERDES_MODE = 0,
    parameter SRVAL_OQ = 0,
    parameter SRVAL_TQ = 0,
    parameter TBYTE_CTL = 0,
    parameter TBYTE_SRC = 0,
    parameter TRISTATE_WIDTH = 0) (
    input  wire OFB,
    output wire OQ,
    input  wire SHIFTOUT1,
    input  wire SHIFTOUT2,
    input  wire TBYTEOUT,
    input  wire TFB,
    input  wire TQ,
    input  wire CLK,
    input  wire CLKDIV,
    input  wire D1,
    input  wire D2,
    input  wire D3,
    input  wire D4,
    input  wire D5,
    input  wire D6,
    input  wire D7,
    input  wire D8,
    input  wire OCE,
    input  wire RST,
    input  wire SHIFTIN1,
    input  wire SHIFTIN2,
    input  wire T1,
    input  wire T2,
    input  wire T3,
    input  wire T4,
    input  wire TBYTEIN,
    input  wire TCE,
    input  wire GSR);

reg CLKDIV_d = 0;
reg CLK_d;
always @(CLK) begin
    CLK_d = #0.1 CLK;
end

wire [7:0] parReg = { D8, D7, D6, D5, D4, D3, D2, D1 };
reg [DATA_WIDTH-1:0] shiftReg = 0;
assign OQ = shiftReg[0];

always @(posedge CLK_d) begin
    if (CLKDIV && !CLKDIV_d) begin
        shiftReg = parReg[DATA_WIDTH-1:0];
    end
    else begin
        shiftReg = shiftReg >> 1;
    end
    CLKDIV_d = CLKDIV;
end
always @(negedge CLK_d) begin
    shiftReg = shiftReg >> 1;
end

endmodule
`default_nettype wire
