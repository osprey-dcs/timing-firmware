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
 * Test tiny event generator
 */
`timescale 1ns/1ns

`default_nettype none
module tinyEVG_tb;

localparam DISTRIBUTED_BUFFER_ADDRESS_WIDTH = 11;

reg                                         sysClk = 0;
reg                                         sysWriteStrobe = 0;
reg  [DISTRIBUTED_BUFFER_ADDRESS_WIDTH-1:0] sysAddress;
reg                                   [7:0] sysData;
reg                                   [7:0] sysSendStrobe = 0;
wire                                        sysBusy;

reg         evgClk = 0;
reg         eventStrobe = 0;
reg   [7:0] eventCode = {8{1'bx}};
reg         heartbeatRequest = 0;
wire        ppsStrobe;
reg         secondsStrobe = 0;
reg  [31:0] posixSeconds = 0;
reg   [7:0] distributedBus = 8'hAB;
wire [15:0] evgTxChars;
wire  [1:0] evgTxCharIsK;
wire                        evgCodeTVALID;

// Instantiate the device under test
tinyEVG #(
    .DISTRIBUTED_BUFFER_ADDRESS_WIDTH(DISTRIBUTED_BUFFER_ADDRESS_WIDTH))
  tinyEVG_i (
    .evgTxClk(evgClk),
    .evgTxWord(evgTxChars),
    .evgTxIsK(evgTxCharIsK),
    .eventCode(eventCode),
    .eventStrobe(eventStrobe),
    .heartbeatRequest(heartbeatRequest),
    .ppsStrobe(ppsStrobe),
    .secondsStrobe(secondsStrobe),
    .seconds(posixSeconds),
    .distributedBus(distributedBus),
    .sysClk(1'b0),
    .sysWriteStrobe(1'b0),
    .sysAddress({DISTRIBUTED_BUFFER_ADDRESS_WIDTH{1'b0}}),
    .sysData(8'h00),
    .sysSendStrobe(1'b0),
    .sysBusy());

// Generate clocks
always begin #5 sysClk = !sysClk; end
always begin #4 evgClk = !evgClk; end

//
integer len, i, e;
integer good = 1;
initial
begin
    $dumpfile("tinyEVG_tb.fst");
    $dumpvars(0, tinyEVG_tb);

    #100 ;
    setTOD(32'h12345678);
    sendEvent(8'h02);
    #5000000 $finish;
end

// Send event code
task sendEvent;
    input  [7:0] code;
    begin
    @(posedge evgClk) begin
        eventCode <= code;
        eventStrobe <= 1;
    end
    @(posedge evgClk) begin
        eventCode <= {8{1'bx}};;
        eventStrobe <= 0;
    end
    end
endtask

// Set time-of-day
task setTOD;
    input  [31:0] seconds;
    begin
    @(posedge evgClk) begin
        posixSeconds <= seconds;
        secondsStrobe <= 1;
    end
    @(posedge evgClk) begin
        posixSeconds <= {2{1'bx}};;
        secondsStrobe <= 0;
    end
    end
endtask

// Generate PPS markers
reg [18:0] ppsDivider = 0;
assign ppsStrobe = ppsDivider[18];
always @(posedge evgClk) begin
    ppsDivider <= ppsStrobe ? 0 : ppsDivider + 1;
end

// Report events
always @(posedge evgClk) begin
    if ((evgTxChars[15:8] != 0) && (evgTxCharIsK[1] == 0)) begin
        $display("%d %d", $time, evgTxChars[15:8]);
    end
end
endmodule
`default_nettype wire
