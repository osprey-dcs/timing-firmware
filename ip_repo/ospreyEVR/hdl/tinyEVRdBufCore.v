// MIT License
//
// Copyright (c) 2024 Osprey DCS
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// Distributed buffer core of MRF-compatible event receiver
// Very simple, single buffer only.
// Nets with names beginning with 'sys' are in the system clock (sysClk) domain.

module tinyEVRdBufCore #(
    parameter DISTRIBUTED_BUFFER_ADDRESS_WIDTH = 11,
    parameter DEBUG                            = "false"
    ) (
    // Connection to system
    input  wire        sysClk,
    input  wire        sysCSRstrobe,
    input  wire [31:0] sysGPIO_OUT,
    (*MARK_DEBUG=DEBUG*)
    output wire [31:0] sysStatus,
    (*MARK_DEBUG=DEBUG*)
    input  wire [DISTRIBUTED_BUFFER_ADDRESS_WIDTH-1:0] sysAddr,
    (*MARK_DEBUG=DEBUG*)
    output wire [31:0] sysData,

    // Connection to receiver
    input  wire        evrRxClk,
    (*MARK_DEBUG=DEBUG*)
    input  wire [15:0] evrRxWord,
    (*MARK_DEBUG=DEBUG*)
    input  wire  [1:0] evrRxIsK);

localparam DPRAM_ADDR_WIDTH = DISTRIBUTED_BUFFER_ADDRESS_WIDTH - 2;

localparam EVCODE_K28_0 = 8'h1C;
localparam EVCODE_K28_1 = 8'h3C;
localparam EVCODE_K28_5 = 8'hBC;

// Dual-port RAM
reg [31:0] dpram[0:(1 << DPRAM_ADDR_WIDTH) - 1], dpramQ;
wire [DPRAM_ADDR_WIDTH-1:0] sysDpramRaddr = sysAddr[2+:DPRAM_ADDR_WIDTH];

///////////////////////////////////////////////////////////////////////////////
// System clock domain

// Forward references to receiver clock domain.
reg rxDone = 0;
reg rxOverrun = 0;
reg rxOverflow = 0;
reg rxError = 0;
reg [DISTRIBUTED_BUFFER_ADDRESS_WIDTH:0] rxCounter = 0;

// Hand buffer ownership back to EVR
reg sysAckToggle = 0;

/*
 * Need this full clock crossing logic only for 'done'.
 * The error bits will be stable by the time sysRxDone is asserted.
 */
(*ASYNC_REG="true"*) reg sysRxDone_m = 0;
reg sysRxDone = 0;


always @(posedge sysClk) begin
    dpramQ <= dpram[sysDpramRaddr];
    if (sysCSRstrobe) begin
        if (sysGPIO_OUT[31]) begin
            sysAckToggle <= !sysAckToggle;
        end
    end
    sysRxDone_m <= rxDone;
    sysRxDone   <= sysRxDone_m;
end
assign sysData = dpramQ;

assign sysStatus = {
    sysRxDone, rxOverrun, rxOverflow, rxError,
    {32-4-(DISTRIBUTED_BUFFER_ADDRESS_WIDTH+1){1'b0}},
    rxCounter };

///////////////////////////////////////////////////////////////////////////////
// Event receiver clock domain

wire [DISTRIBUTED_BUFFER_ADDRESS_WIDTH-1:0] rxAddr =
                                rxCounter[DISTRIBUTED_BUFFER_ADDRESS_WIDTH-1:0];
wire rxCounterDone = rxCounter[DISTRIBUTED_BUFFER_ADDRESS_WIDTH];
wire [DPRAM_ADDR_WIDTH-1:0] dpramWaddr = rxCounter[2+:DPRAM_ADDR_WIDTH];
wire [1:0] dpramByteSel = rxCounter[1:0];

// Buffer reception state machine
localparam S_IDLE   = 2'd0,
           S_DATA   = 2'd1,
           S_CHK_HI = 2'd2,
           S_CHK_LO = 2'd3;
(*MARK_DEBUG=DEBUG*) reg  [1:0] state = S_IDLE;
(*MARK_DEBUG=DEBUG*) reg [15:0] checksum;
reg        bufferSlot;

// Communication from system
(*ASYNC_REG="true"*) reg ackToggle_m = 0;
reg ackToggle = 0, ackToggle_d = 0;

always @(posedge evrRxClk) begin
    ackToggle_m <= sysAckToggle;
    ackToggle   <= ackToggle_m;
    ackToggle_d <= ackToggle;
    if (ackToggle != ackToggle_d) begin
        rxDone <= 0;
        rxOverrun <= 0;
        rxOverflow <= 0;
        rxError <= 0;
        rxCounter <= 0;
        state <= S_IDLE;
    end
    else if (state == S_IDLE) begin
        bufferSlot <= 0;
        checksum <= 0;
        if (evrRxIsK[1] && (evrRxWord[15:8] == EVCODE_K28_0)) begin
            if (rxDone) begin
                rxOverrun <= 1;
            end
            else begin
                state <= S_DATA;
            end
        end
    end
    else begin
        bufferSlot <= !bufferSlot;
        if (bufferSlot) begin
            case (state)
            S_DATA: begin
                if (evrRxIsK[1]) begin
                    if (evrRxWord[15:8] == EVCODE_K28_1) begin
                        state <= S_CHK_HI;
                    end
                    else begin
                        rxError <= 1;
                        rxDone <= 1;
                        state <= S_IDLE;
                    end
                end
                else if (rxCounterDone) begin
                    rxOverflow <= 1;
                    rxDone <= 1;
                    state <= S_IDLE;
                end
                else begin
                    rxCounter <= rxCounter + 1;
                    dpram[dpramWaddr][dpramByteSel*8+:8] <= evrRxWord[15:8];
                    checksum <= checksum + {8'h0, evrRxWord[15:8]};
                end
            end
            S_CHK_HI: begin
                if (evrRxIsK[1] || (evrRxWord[15:8] != ~checksum[15:8])) begin
                    rxError <= 1;
                    rxDone <= 1;
                    state <= S_IDLE;
                end
                else begin
                    state <= S_CHK_LO;
                end
            end
            S_CHK_LO: begin
                if (evrRxIsK[1] || (evrRxWord[15:8] != ~checksum[7:0])) begin
                    rxError <= 1;
                end
                rxDone <= 1;
                state <= S_IDLE;
            end
            default: state <= S_IDLE;
            endcase
        end
    end
end

endmodule
