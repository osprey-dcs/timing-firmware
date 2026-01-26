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
 * Generate table-based event sequence
 */
`default_nettype none
module ospreyEVGsequencer #(
    parameter SEQUENCE_CAPACITY = 2048,
    parameter BANK_COUNT        = 2,
    parameter HW_TRIGGER_COUNT  = 4,
    parameter GAP_WIDTH         = 32,
    parameter DB_WIDTH          = 32,
    parameter EVCODE_WIDTH      = 8,
    parameter DEBUG             = "false",
    parameter DPRAM_TYPE        = "auto"
    ) (
    input  wire                sysClk,
    input  wire                sysCsrStrobe,
    input  wire                sysAddressCodeStrobe,
    input  wire                sysGapStrobe,
    input  wire [DB_WIDTH-1:0] sysGPIO_OUT,
    output wire [DB_WIDTH-1:0] sysStatus,
    output wire [DB_WIDTH-1:0] sysAddressCodeRbk,
    output wire [DB_WIDTH-1:0] sysGapRbk,

    input  wire                        evgClk,
    input  wire [HW_TRIGGER_COUNT-1:0] evgHwTriggerRising,
    input  wire [HW_TRIGGER_COUNT-1:0] evgHwTriggerFalling,
    output reg      [EVCODE_WIDTH-1:0] evgCodeTDATA,
    output reg                         evgCodeTVALID = 0);

localparam EVCODE_END    = {EVCODE_WIDTH{1'b1}};
localparam EVCODE_REPEAT = {{EVCODE_WIDTH-1{1'b1}}, 1'b0};

localparam GAP_COUNTER_WIDTH = GAP_WIDTH + 1;
localparam SEQ_ADDR_WIDTH      = $clog2(SEQUENCE_CAPACITY);
localparam ADDR_COUNTER_WIDTH  = SEQ_ADDR_WIDTH + 1;
localparam BANKSEL_WIDTH       = $clog2(BANK_COUNT);
localparam DPRAM_ADDR_WIDTH    = BANKSEL_WIDTH + SEQ_ADDR_WIDTH;

/*
 * Dual-port memory.
 * Read/Write from sysClk side.
 * Read-only from evgClk side.
 * For very high data rates DPRAM_TYPE must be "distributed".
 */
(* RAM_STYLE = DPRAM_TYPE *)
reg      [EVCODE_WIDTH-1:0] dpramCodes[0:(BANK_COUNT*(1<<SEQ_ADDR_WIDTH))-1];
reg      [EVCODE_WIDTH-1:0] sysDpramQcodes;
reg [GAP_COUNTER_WIDTH-1:0] dpramGaps [0:(BANK_COUNT*(1<<SEQ_ADDR_WIDTH))-1];
reg [GAP_COUNTER_WIDTH-1:0] sysDpramQgaps;

/*
 * Other forward references
 */
(*MARK_DEBUG=DEBUG*) reg                     evgActive = 0;
(*MARK_DEBUG=DEBUG*) reg [BANKSEL_WIDTH-1:0] evgActiveBankIndex = 0;
(*MARK_DEBUG=DEBUG*) reg    [BANK_COUNT-1:0] evgArmed = 0;
(*MARK_DEBUG=DEBUG*) reg    [BANK_COUNT-1:0] evgTriggered = 0;

///////////////////////////////////////////////////////////////////////////////
// System clock domain

reg [DB_WIDTH-1:0] sysCSR;
reg sysArmInfoToggle = 0;
reg sysSoftTriggerToggle = 0;
reg sysSeqCancelToggle = 0;
reg sysHwTrigInfoToggle = 0;
reg   [DPRAM_ADDR_WIDTH-1:0] sysAddrLatch = 0;
wire  [DPRAM_ADDR_WIDTH-1:0] sysAddr = sysGPIO_OUT[8+:DPRAM_ADDR_WIDTH];
wire [GAP_COUNTER_WIDTH-1:0] sysGapVal = {1'b0, sysGPIO_OUT[GAP_WIDTH-1:0]} +
                                                      {GAP_COUNTER_WIDTH{1'b1}};

always @(posedge sysClk) begin
    if (sysCsrStrobe) begin
        sysCSR <= sysGPIO_OUT;
        if (sysGPIO_OUT[31]) begin
            sysSeqCancelToggle <= !sysSeqCancelToggle;
        end
        if (sysGPIO_OUT[30]) begin
            sysSoftTriggerToggle <= !sysSoftTriggerToggle;
        end
        else if (sysGPIO_OUT[29]) begin
            sysHwTrigInfoToggle  <= !sysHwTrigInfoToggle;
        end
        else begin
            sysArmInfoToggle <= !sysArmInfoToggle;
        end
    end
    if (sysAddressCodeStrobe) begin
        if (sysGPIO_OUT[31]) begin
            dpramCodes[sysAddr] <= sysGPIO_OUT[0+:EVCODE_WIDTH];
        end
        sysAddrLatch <= sysGPIO_OUT[EVCODE_WIDTH+:DPRAM_ADDR_WIDTH];
    end
    if (sysGapStrobe) begin
        dpramGaps[sysAddrLatch] <= sysGapVal;
    end
    sysDpramQcodes <= dpramCodes[sysAddrLatch];
    sysDpramQgaps  <= dpramGaps[sysAddrLatch];
end

assign sysStatus = { {32-1-BANKSEL_WIDTH-16{1'b0}},
                     evgActive, evgActiveBankIndex,
                     {8-BANK_COUNT{1'b0}}, evgTriggered,
                     {8-BANK_COUNT{1'b0}}, evgArmed };
assign sysAddressCodeRbk = { {DB_WIDTH-DPRAM_ADDR_WIDTH-EVCODE_WIDTH{1'b0}},
                             sysAddrLatch, sysDpramQcodes };
assign sysGapRbk = { {DB_WIDTH-GAP_WIDTH{1'b0}},
                      sysDpramQgaps + {{GAP_WIDTH-1{1'b0}},1'b1} };

///////////////////////////////////////////////////////////////////////////////
// Event generator clock domain

/*
 * EVG clock side of dual-port RAMs
 */
reg [GAP_COUNTER_WIDTH-1:0] evgDpramQgap;
reg      [EVCODE_WIDTH-1:0] evgDpramQcode;
wire evgDpramNoGap = evgDpramQgap[GAP_COUNTER_WIDTH-1];

/*
 * Arm/Disarm
 */
(*ASYNC_REG="true"*) reg evgArmInfoToggle_m = 0;
reg evgArmInfoToggle = 0, evgArmInfoToggle_d = 0;
reg [BANK_COUNT-1:0] evgArm = 0, evgDisarm = 0;
reg [BANK_COUNT-1:0] evgStartedBitmap = 0;
always @(posedge evgClk) begin
    evgArmInfoToggle_m <= sysArmInfoToggle;
    evgArmInfoToggle   <= evgArmInfoToggle_m;
    evgArmInfoToggle_d <= evgArmInfoToggle;
    if (evgArmInfoToggle != evgArmInfoToggle_d) begin
        evgArm <= sysCSR[0+:BANK_COUNT];
        evgDisarm <= sysCSR[8+:BANK_COUNT];
    end
    else begin
        evgArm <= 0;
        evgDisarm <= 0;
    end
    evgArmed <= (evgArmed | evgArm) & ~evgDisarm & ~evgStartedBitmap;
end

/*
 * Triggering
 */
wire  [BANKSEL_WIDTH-1:0] sysHwTrigInfoBank = sysCSR[21+:BANKSEL_WIDTH];
wire                      sysHwTrigInfoEdge = sysCSR[20];
wire[HW_TRIGGER_COUNT-1:0]sysHwTrigInfoEnables=sysCSR[0+:HW_TRIGGER_COUNT];
(*ASYNC_REG="true"*) reg evgHwTrigInfoToggle_m = 0;
reg evgHwTrigInfoToggle = 0, evgHwTrigInfoToggle_d = 0;
reg [HW_TRIGGER_COUNT-1:0] evgHwTrigRiseEnables [0:BANK_COUNT-1];
reg [HW_TRIGGER_COUNT-1:0] evgHwTrigFallEnables [0:BANK_COUNT-1];
reg [BANK_COUNT-1:0] evgHwTriggers = 0;

(*ASYNC_REG="true"*) reg evgSoftTriggerToggle_m = 0;
reg evgSoftTriggerToggle = 0, evgSoftTriggerToggle_d = 0;
reg [BANK_COUNT-1:0] evgSoftTriggers = 0;

/*
 * Emergency stop
 */
(*ASYNC_REG="true"*) reg evgSeqCancelToggle_m = 0;
reg evgSeqCancelToggle = 0, evgSeqCancelToggle_d = 0;
(*MARK_DEBUG=DEBUG*) reg evgSeqCancel = 0;

always @(posedge evgClk) begin
    /*
     * Get hardware trigger configuration from system
     */
    evgHwTrigInfoToggle_m <= sysHwTrigInfoToggle;
    evgHwTrigInfoToggle   <= evgHwTrigInfoToggle_m;
    evgHwTrigInfoToggle_d <= evgHwTrigInfoToggle;
    if (evgHwTrigInfoToggle != evgHwTrigInfoToggle_d) begin
        if (sysHwTrigInfoEdge) begin
            evgHwTrigFallEnables[sysHwTrigInfoBank] <= sysHwTrigInfoEnables;
        end
        else begin
            evgHwTrigRiseEnables[sysHwTrigInfoBank] <= sysHwTrigInfoEnables;
        end
    end
    
    /*
     * Get software trigger requests from system
     */
    evgSoftTriggerToggle_m <= sysSoftTriggerToggle;
    evgSoftTriggerToggle   <= evgSoftTriggerToggle_m;
    evgSoftTriggerToggle_d <= evgSoftTriggerToggle;
    if (evgSoftTriggerToggle != evgSoftTriggerToggle_d) begin
        evgSoftTriggers <= sysCSR[0+:BANK_COUNT] & evgArmed;
    end
    else begin
        evgSoftTriggers <= 0;
    end

    /*
     * Generate trigger requests
     */
    evgTriggered <= (evgTriggered | evgHwTriggers | evgSoftTriggers) &
                                                                 evgArmed;

    /*
     * Cancel sequencer on request
     */
    evgSeqCancelToggle_m <= sysSeqCancelToggle;
    evgSeqCancelToggle   <= evgSeqCancelToggle_m;
    evgSeqCancelToggle_d <= evgSeqCancelToggle;
    evgSeqCancel <= (evgSeqCancelToggle != evgSeqCancelToggle_d);
end

genvar b;
generate
for (b = 0 ; b < BANK_COUNT ; b = b + 1) begin
always @(posedge evgClk) begin
    evgHwTriggers[b] <= |(((evgHwTriggerRising  & evgHwTrigRiseEnables[b]) |
                           (evgHwTriggerFalling & evgHwTrigFallEnables[b]))) &
                                                              evgArmed[b];
end
end
endgenerate

/*
 * State machine
 */
reg evgStart = 0, evgStarting = 0;
reg [ADDR_COUNTER_WIDTH-1:0] evgAddrCounter = 0;
wire evgAddrOverflow = evgAddrCounter[ADDR_COUNTER_WIDTH-1];
reg evgAddrOverflow_r = 0;
(*MARK_DEBUG=DEBUG*) wire [DPRAM_ADDR_WIDTH-1:0] evgRdAddr =
                       {evgActiveBankIndex, evgAddrCounter[SEQ_ADDR_WIDTH-1:0]};
(*MARK_DEBUG=DEBUG*) reg [GAP_COUNTER_WIDTH-1:0] evgGapCounter = 0;
(*MARK_DEBUG=DEBUG*) wire evgGapCounterDone=evgGapCounter[GAP_COUNTER_WIDTH-1];
reg evgInGap = 0, evgStop = 0;
wire evgReadEnable = !evgInGap;

integer i, brk;
always @(posedge evgClk) begin
    /*
     * EVG side of dual-port RAM
     */
    if (evgReadEnable) begin
        evgDpramQcode <= dpramCodes[evgRdAddr];
        evgDpramQgap  <= dpramGaps[evgRdAddr];
        evgAddrOverflow_r <= evgAddrOverflow;
    end

    /*
     * Act on trigger requests
     */
    if (evgStart || evgActive) begin
        evgStart <= 0;
        evgStartedBitmap <= 0;
    end
    else begin
        brk = 0;
        for (i = BANK_COUNT - 1 ; i >= 0 ; i = i - 1) begin
            if (evgTriggered[i] && !brk) begin
                evgActiveBankIndex <= i;
                evgStartedBitmap <= 1 << i;
                evgStart <= 1;
                brk = 1;
            end
        end
    end

    /*
     * Sequencer state machine
     */
    if (evgStarting) begin
        evgAddrCounter <= 1;
        evgStarting <= 0;
    end
    else if (evgActive) begin
        if (evgSeqCancel) begin
            evgInGap <= 0;
            evgStop <= 0;
            evgAddrCounter <= 0;
            evgCodeTVALID <= 0;
            evgActive <= 0;
        end
        else if (evgInGap) begin
            evgGapCounter <= evgGapCounter - 1;
            if (evgGapCounterDone) begin
                if (!evgStop) evgCodeTVALID <= 1;
                evgInGap <= 0;
            end
        end
        else if (evgStop || evgAddrOverflow_r) begin
            evgStop <= 0;
            evgAddrCounter <= 0;
            evgCodeTVALID <= 0;
            evgActive <= 0;
        end
        else begin
            evgAddrCounter <= evgAddrCounter + 1;
            evgCodeTDATA <= evgDpramQcode;
            evgGapCounter <= evgDpramQgap + {GAP_COUNTER_WIDTH{1'b1}};
            if (evgDpramQcode == EVCODE_END) begin
                evgCodeTVALID <= 0;
                evgStop <= 1;
            end
            else begin
                evgCodeTVALID <= evgDpramNoGap;
            end
            evgInGap <= !evgDpramNoGap;
        end
    end
    else if (evgStart) begin
        evgStarting <= 1;
        evgActive <= 1;
    end

end
endmodule
`default_nettype wire
