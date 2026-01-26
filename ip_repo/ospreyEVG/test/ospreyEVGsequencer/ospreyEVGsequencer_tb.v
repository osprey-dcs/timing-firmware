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
 * Test event sequence generator
 */
`timescale 1ns/100ps

`default_nettype none
module ospreyEVGsequencer_tb;

localparam SEQUENCE_CAPACITY = 2048;
localparam BANK_COUNT        = 4;
localparam HW_TRIGGER_COUNT  = 8;
localparam DB_WIDTH          = 32;
localparam GAP_WIDTH         = 32;
localparam EVCODE_WIDTH      = 8;

wire [DB_WIDTH-1:0] undefBus = {DB_WIDTH{1'bx}};

reg                 sysClk = 0;
reg                 sysCsrStrobe = 0;
reg                 sysAddressCodeStrobe = 0;
reg                 sysGapStrobe = 0;
reg  [DB_WIDTH-1:0] sysGPIO_OUT;
wire [DB_WIDTH-1:0] sysStatus;
wire [DB_WIDTH-1:0] sysAddressCodeRbk;
wire [DB_WIDTH-1:0] sysGapRbk;

reg                         evgClk = 0;
reg  [HW_TRIGGER_COUNT-1:0] evgHwTriggerRising = 0;
reg  [HW_TRIGGER_COUNT-1:0] evgHwTriggerFalling = 0;
wire     [EVCODE_WIDTH-1:0] evgCodeTDATA;
wire                        evgCodeTVALID;

// Instantiate device under test
ospreyEVGsequencer #(
    .SEQUENCE_CAPACITY(SEQUENCE_CAPACITY),
    .BANK_COUNT(BANK_COUNT),
    .HW_TRIGGER_COUNT(HW_TRIGGER_COUNT),
    .GAP_WIDTH(GAP_WIDTH),
    .DB_WIDTH(DB_WIDTH),
    .EVCODE_WIDTH(EVCODE_WIDTH))
  ospreyEVGsequencer_i (
    .sysClk(sysClk),
    .sysCsrStrobe(sysCsrStrobe),
    .sysAddressCodeStrobe(sysAddressCodeStrobe),
    .sysGapStrobe(sysGapStrobe),
    .sysGPIO_OUT(sysGPIO_OUT),
    .sysStatus(sysStatus),
    .sysAddressCodeRbk(sysAddressCodeRbk),
    .sysGapRbk(sysGapRbk),
    .evgClk(evgClk),
    .evgHwTriggerRising(evgHwTriggerRising),
    .evgHwTriggerFalling(evgHwTriggerFalling),
    .evgCodeTDATA(evgCodeTDATA),
    .evgCodeTVALID(evgCodeTVALID));

// Generate clocks
always begin #5 sysClk = !sysClk; end
always begin #4 evgClk = !evgClk; end

integer len, i, e;
integer good = 1;
initial
begin
    $dumpfile("ospreyEVGsequencer_tb.fst");
    $dumpvars(0, ospreyEVGsequencer_tb);

    // Enable first bank
    $display("Zero gap sequences");
    for (len = 0 ; len <= 4 ; len = len + 1) begin
        for (i = 0 ; i < len ; i = i + 1) begin
            writeRAM(0, i, i+1, 0);
        end
        writeRAM(0, i, 255, 0);
        armSequencer(1);
        softTrigger(1);
    end

    $display("Non-zero gap sequences");
    for (len = 4 ; len <= 4 ; len = len + 1) begin
        for (i = 0 ; i < len ; i = i + 1) begin
            writeRAM(1, i, i+11, i+1);
        end
        writeRAM(1, len, 255, 0);
        armSequencer(2);
        softTrigger(2);
    end

    $display("Different trailing delay");
    for (i = 0 ; i < 3 ; i = i + 1) begin
        writeRAM(0, 4, 255, i*10);
        armSequencer(3);
        softTrigger(3);
    end

    $display("Unterminated sequence");
    e = 0;
    for (i = 0 ; i < SEQUENCE_CAPACITY ; i = i + 1) begin
        e = (e == {{EVCODE_WIDTH-1{1'b1}},1'b0}) ? 1 : e + 1;
        writeRAM(0, i, e, 0);
    end
    armSequencer(1);
    softTrigger(1);

    $display("Full-length sequence");
    writeRAM(0, SEQUENCE_CAPACITY - 1, 255, 4);
    armSequencer(1);
    softTrigger(1);
    awaitCompletion();

    // Initialize hardware trigger configuration
    for (i = 0 ; i < BANK_COUNT ; i = i + 1) begin
        configureHardwareTrigger(i, 0, 0);
        configureHardwareTrigger(i, 1, 0);
    end
    $display("Bank 0 on trigger 1 rising, bank 1 on falling");
    configureHardwareTrigger(0, 0, 2);
    configureHardwareTrigger(1, 1, 2);
    for (i = 0 ; i < 4 ; i = i + 1) begin
        writeRAM(0, i, i+1, i+1);
        writeRAM(1, i, i+11, i+1);
    end
    writeRAM(0, 4, 255, 0);
    writeRAM(1, 4, 255, 0);
    armSequencer(3);
    #30;
    hardTriggerRise(2);
    while (!sysStatus[31]) @(posedge evgClk);
    hardTriggerFall(2);
    awaitCompletion();

    #100;
    $display("%s", good ? "PASS" : "FAIL");
    $finish;
end

// Arm sequencer(s)
task armSequencer;
    input  [BANK_COUNT-1:0] banks;
    begin
    writeCSR({{32-BANK_COUNT{1'b0}}, banks});
    end
endtask

// Disarm sequencer(s)
task disarmSequencer;
    input  [BANK_COUNT-1:0] banks;
    begin
    writeCSR({{32-8-BANK_COUNT{1'b0}}, banks, {8{1'b0}}});
    end
endtask

// Generate software trigger(s)
task softTrigger;
    input  [BANK_COUNT-1:0] banks;
    begin
    $display("Soft trigger bank%s 0x%X", (banks & (banks-1)) ? "s" : "", banks);
    writeCSR({3'b010, {32-3-BANK_COUNT{1'b0}}, banks});
    awaitCompletion();
    end
endtask

// Configure hardware trigger
task configureHardwareTrigger;
    input [$clog2(BANK_COUNT)-1:0] bankSel;
    input                          edgeSel;
    input   [HW_TRIGGER_COUNT-1:0] enables;
    begin
    writeCSR({3'b001, {32-3-$clog2(BANK_COUNT)-21{1'b0}}, bankSel, edgeSel,
                                         {20-HW_TRIGGER_COUNT{1'b0}}, enables});
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
        sysGPIO_OUT <= undefBus;
        sysCsrStrobe <= 0;
    end
    @(posedge sysClk) ;
    end
endtask

// Write value to sequence RAM
task writeRAM;
    input  [DB_WIDTH-1:0] bank;
    input  [DB_WIDTH-1:0] address;
    input  [DB_WIDTH-1:0] code;
    input  [DB_WIDTH-1:0] gap;
    begin
    @(posedge sysClk) begin
        sysGPIO_OUT <= {1'b1,
                       {DB_WIDTH - 1 - $clog2(BANK_COUNT) -
                                $clog2(SEQUENCE_CAPACITY) - EVCODE_WIDTH{1'bx}},
                        bank[0+:$clog2(BANK_COUNT)],
                        address[0+:$clog2(SEQUENCE_CAPACITY)],
                        code[0+:EVCODE_WIDTH]};
        sysAddressCodeStrobe <= 1;

    end
    @(posedge sysClk) begin
        sysAddressCodeStrobe <= 0;
        sysGPIO_OUT <= gap;
        sysGapStrobe <= 1;
    end
    @(posedge sysClk) begin
        sysGPIO_OUT <= undefBus;
        sysGapStrobe <= 0;
    end
    @(posedge sysClk) ;
    end
endtask

// Generate hard trigger
task hardTriggerRise;
    input  [BANK_COUNT-1:0] triggers;
    begin
    @(posedge evgClk) begin
        evgHwTriggerRising <= triggers;
    end
    @(posedge evgClk) begin
        evgHwTriggerRising <= 0;
    end
    end
endtask
task hardTriggerFall;
    input  [BANK_COUNT-1:0] triggers;
    begin
    @(posedge evgClk) begin
        evgHwTriggerFalling <= triggers;
    end
    @(posedge evgClk) begin
        evgHwTriggerFalling <= 0;
    end
    end
endtask

// Wait for sequence to complete
integer awaitIdleCount;
task awaitCompletion;
    begin
    awaitIdleCount = 0;
    while (awaitIdleCount < 20) begin
        if (sysStatus[31]) begin
            awaitIdleCount = 0;
        end
        else begin
            awaitIdleCount = awaitIdleCount + 1;
        end
        @(posedge evgClk) ;
    end
    end
endtask

// Report events
wire evgSeqActive = sysStatus[31];
reg evgSeqActive_d = 0;
integer gap = 0;
always @(posedge evgClk) begin
    evgSeqActive_d <= evgSeqActive;
    if (evgSeqActive != evgSeqActive_d) begin
        if (evgSeqActive) begin
            $display("========= BANK %d", sysStatus[28+:3]);
            gap <= -1;
        end
        else begin
            $display("%4d DONE", gap);
        end
    end
    else begin
        if (evgCodeTVALID) begin
            gap <= 0;
            $display("%4d %4d", gap, evgCodeTDATA);
        end
        else begin
            gap <= gap + 1;
        end
    end
end

endmodule
`default_nettype wire
