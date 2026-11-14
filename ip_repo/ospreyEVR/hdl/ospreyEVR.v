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
 * Basic MRF-compatible event receiver
 * Nets with names beginning with 'evr' are in the evrClk dommain.
 * 
 * Based on the AXI-lite template with extra read latency.
 */

`timescale  1 ns / 1 ns
`default_nettype none
module ospreyEVR_v1_0 #(
    ////////////////////// Application-specific Parameters ///////////////////
    parameter EVGCLK_FREQUENCY   = 125000000,
    parameter DISTRIBUTED_BUFFER_ADDR_WIDTH = 10,
    parameter HARDWARE_OUTPUT_COUNT         = 24,
    parameter SERDES_FACTOR                 = 8,
    parameter ACTION_STROBES_WIDTH          = 24,
    parameter ACTIVE_LOW_OUTPUTS            = 0,
    parameter DEBUG                         = "false",
    ////////////////////// AXI-Lite Boilerplate Parameters ///////////////////
    parameter C_S_AXI_FREQ_HZ    = 100000000,
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 11
    ) (
    ////////////////////// Application-specific Ports ///////////////////
    /*
     * From MGT
     */
    input  wire        evrClk,
    input  wire        evrBitClk,
    input  wire        evrLinkUp,
    input  wire [15:0] evrRxChars,
    input  wire  [1:0] evrRxCharIsK,

    // Hardware outputs -- must connect to *OBUF primative
    output wire [HARDWARE_OUTPUT_COUNT-1:0] evrHardwareOutputs,
    input  wire [HARDWARE_OUTPUT_COUNT-1:0] hwDriverIn_a,

    /*
     * Internal triggers
     */
    output wire                            evrPPSstrobe,
    output wire                            evrPPSmarker,
    output wire [ACTION_STROBES_WIDTH-1:0] evrActionStrobes,

    /*
     * Distributed bus
     */
    output wire [7:0] evrDistributedBus,

    /*
     * Time stamps
     */
    output wire        evrTimestampValid,
    output wire [63:0] evrTimestamp,
    output reg  [63:0] sysTimestamp = 0,

    ////////////////////// AXI-Lite Boilerplate Ports ///////////////////
    input  wire                          s_axi_aclk,
    input  wire                          s_axi_aresetn,

    input  wire                          s_axi_arvalid,
    output reg                           s_axi_arready = 1,
    input  wire                    [2:0] s_axi_arprot,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    output wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output reg                           s_axi_rvalid = 0,
    input  wire                          s_axi_rready,
    output wire                    [1:0] s_axi_rresp,

    input  wire                          s_axi_awvalid,
    output wire                          s_axi_awready,
    input  wire                    [2:0] s_axi_awprot,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire                          s_axi_wvalid,
    (*MARK_DEBUG=DEBUG*)
    output reg                           s_axi_wready = 0,
    input  wire                    [3:0] s_axi_wstrb,
    (*MARK_DEBUG=DEBUG*)
    input  wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata,
    output reg                           s_axi_bvalid = 0,
    input  wire                          s_axi_bready,
    output wire                    [1:0] s_axi_bresp);

/*
 * Static outputs -- success always
 */
assign s_axi_rresp = 2'b00;
assign s_axi_bresp = 2'b00;

/*
 * Read side
 */
always @(posedge s_axi_aclk)
begin
    if (!s_axi_aresetn) begin
        s_axi_arready <= 1;
        s_axi_rvalid <= 0;
    end
    else if (s_axi_arvalid && s_axi_arready) begin
        s_axi_rvalid <= 1;
        s_axi_arready <= 0;
    end
    else if (s_axi_rready) begin
        s_axi_rvalid <= 0;
        s_axi_arready <= 1;
    end
end

/*
 * AXI write operation state machine
 * Up to 3 EVG clocks are required to pick up values from system clock domain.
 * Fast AXI masters might start a new transaction within this time, so we
 * can't simply latch s_axi_wdata and use the standard, simple, AXI write
 * transaction code.  Instead we add wait states to ensure that the EVG clock
 * code has picked up s_axi_wdata before allowing the transaction to proceed.
 */

// Scale values to avoid 32-bit overflow with high clock speeds.
// Simulate the $ceil() function missing on some Verilogs.
localparam WRITE_WAIT_STATE_COUNT = ((((3 * (C_S_AXI_FREQ_HZ/1000)) +
                   (EVGCLK_FREQUENCY/1000) - 1)) / (EVGCLK_FREQUENCY/1000)) - 2;
localparam WRITE_WAIT_STATE_COUNTER_LOAD = WRITE_WAIT_STATE_COUNT - 1;
localparam WRITE_WAIT_STATE_COUNTER_WIDTH = ((WRITE_WAIT_STATE_COUNTER_LOAD<0) ?
                               1 : $clog2(WRITE_WAIT_STATE_COUNTER_LOAD+1)) + 1;
reg [WRITE_WAIT_STATE_COUNTER_WIDTH-1:0] writeWaitStateCounter;
wire writeWaitStateCounterDone =
                        writeWaitStateCounter[WRITE_WAIT_STATE_COUNTER_WIDTH-1];
reg writeTransactionActive = 0;

assign s_axi_awready = s_axi_wready;
wire sysWriteStrobe = s_axi_awvalid && s_axi_wvalid && !writeTransactionActive;

always @(posedge s_axi_aclk)
begin
    if (!s_axi_aresetn) begin
        s_axi_wready <= 0;
        s_axi_bvalid <= 0;
    end
    else if (writeTransactionActive) begin
        if (s_axi_bvalid) begin
            if (s_axi_bready) begin
                s_axi_bvalid <= 0;
                writeTransactionActive <= 0;
            end
        end
        else if (s_axi_wready) begin
            s_axi_wready <= 0;
            s_axi_bvalid <= 1;
        end
        else if (writeWaitStateCounterDone) begin
            s_axi_wready <= 1;
        end
        else begin
            writeWaitStateCounter <= writeWaitStateCounter - 1;
        end
    end
    else begin
        writeWaitStateCounter <= WRITE_WAIT_STATE_COUNTER_LOAD;
        if (s_axi_awvalid && s_axi_wvalid) begin
            writeTransactionActive <= 1;
        end
    end
end

/*
 * Sanity checks
 */
if ((DISTRIBUTED_BUFFER_ADDR_WIDTH < 9)
 || (DISTRIBUTED_BUFFER_ADDR_WIDTH >= C_S_AXI_ADDR_WIDTH)) begin
    invalid_DISTRIBUTED_BUFFER_ADDR_WIDTH();
end
if ((HARDWARE_OUTPUT_COUNT < 2) || (HARDWARE_OUTPUT_COUNT > 24)) begin
  invalid_HARDWARE_OUTPUT_COUNT();
end
if (HARDWARE_OUTPUT_COUNT > ACTION_STROBES_WIDTH) begin
  HARDWARE_OUTPUT_COUNT_must_not_exceed_ACTION_STROBES_WIDTH();
end
if ((SERDES_FACTOR!=1) && (SERDES_FACTOR!=4)
 && (SERDES_FACTOR!=6) && (SERDES_FACTOR!=8)) begin
  invalid_SERDES_FACTOR();
end
if ((ACTION_STROBES_WIDTH < 12) || (ACTION_STROBES_WIDTH > 30)) begin
  invalid_ACTION_STROBES_WIDTH();
end

/*
 * Extract values from AXI addresses
 * Bottom half of address space (s_axi_awaddr[DISTRIBUTED_BUFFER_ADDR_WIDTH] == 0):
 *     0 to 63   -- Sixteen 32-bit registers
 *   256 to 511  -- Space for four 32-bit registers per hardware output
 * Top half of address space is distributed buffer
 */
localparam REGSEL_WIDTH = 4;
wire [REGSEL_WIDTH-1:0] wRegIndex = s_axi_awaddr[2+:REGSEL_WIDTH];
wire [REGSEL_WIDTH-1:0] rRegIndex = s_axi_araddr[2+:REGSEL_WIDTH];
wire wAddrIsDBUF = s_axi_awaddr[DISTRIBUTED_BUFFER_ADDR_WIDTH];
wire rAddrIsDBUF = s_axi_araddr[DISTRIBUTED_BUFFER_ADDR_WIDTH];

localparam [REGSEL_WIDTH-1:0] REG_INDEX_CSR               = 0,
                              REG_INDEX_RAVEL             = 1,
                              REG_INDEX_TIMESTAMP_SECONDS = 2,
                              REG_INDEX_TIMESTAMP_TICKS   = 3,
                              REG_INDEX_ACTION_RAM        = 4,
                              REG_INDEX_FIFO_EVENT        = 5,
                              REG_INDEX_FIFO_SECONDS      = 6,
                              REG_INDEX_FIFO_TICKS        = 7,
                              REG_INDEX_TRIGGER_SELECT    = 8,
                              REG_INDEX_TRIGGER_CONTROL   = 9,
                              REG_INDEX_TRIGGER_DELAY     = 10,
                              REG_INDEX_TRIGGER_WIDTH     = 11;

/*
 * Hardware output control registers
 */
localparam OUTPUT_TRIGGER_SEL_WIDTH = $clog2(HARDWARE_OUTPUT_COUNT);
reg [OUTPUT_TRIGGER_SEL_WIDTH-1:0] sysOutputDriverSel = 0;
// remap physical to logical outputs.  array index is physical.  array value is logical.
// SW responsible for ensuring a 1-to-1 mapping
reg [OUTPUT_TRIGGER_SEL_WIDTH-1:0] sysOutputRavel [0:HARDWARE_OUTPUT_COUNT-1];
reg [HARDWARE_OUTPUT_COUNT-1:0] sysControlUpdateToggles = 0,
                                sysDelayCountUpdateToggles = 0,
                                sysWidthCountUpdateToggles = 0;
reg [C_S_AXI_DATA_WIDTH-1:0] sysControlUpdateData = 0,
                             sysDelayCountUpdateData = 0,
                             sysWidthCountUpdateData = 0;

genvar o;
for(o=0; o<HARDWARE_OUTPUT_COUNT; o=o+1) begin : ravelInit
    initial sysOutputRavel[o] = o;
end

/*
 * Distributed buffer readout
 */
wire [31:0] distributedBufferData = 0;

/*
 * Instantiate core EVR
 */
wire coreWriteStrobe = (sysWriteStrobe && !wAddrIsDBUF &&
                                           (wRegIndex == REG_INDEX_ACTION_RAM));
wire [(ACTION_STROBES_WIDTH+2)-1:0] evrRawActions;
assign evrActionStrobes  = evrRawActions[0+:ACTION_STROBES_WIDTH];
//wire evrInterruptRequest = evrRawActions[ACTION_STROBES_WIDTH];
wire evrFifoWriteEnable  = evrRawActions[ACTION_STROBES_WIDTH+1];
wire [31:0] sysActionReadback;
smallEVR #(
    // 2 extra bits for FIFO log and (unused) IRQ
    .ACTION_WIDTH(ACTION_STROBES_WIDTH+2),
    .DEBUG(DEBUG),
    .TIMESTAMP_WIDTH(64))
  ospreyEVRsmallEVR_i (
    .evrRxClk(evrClk),
    .evrRxWord(evrRxChars & {16{evrLinkUp}}),
    .evrCharIsK(evrRxCharIsK),
    .ppsMarker(evrPPSstrobe),
    .timestampValid(evrTimestampValid),
    .timestamp(evrTimestamp),
    .distributedDataBus(evrDistributedBus),
    .action(evrRawActions),
    .sysClk(s_axi_aclk),
    .sysActionWriteEnable(coreWriteStrobe),
    .sysActionSetting(s_axi_wdata),
    .sysActionReadback(sysActionReadback));

/*
 * Startup sequencing
 * Hold SERDES in reset for a while after startup
 */
localparam SERDES_RESET_TIMER_WIDTH = 12;
reg [SERDES_RESET_TIMER_WIDTH-1:0] serdesResetTimer = ~0;
wire evrResetSERDES = serdesResetTimer[SERDES_RESET_TIMER_WIDTH-1];
always @(posedge evrClk) begin
    if (evrResetSERDES) begin
        serdesResetTimer <= serdesResetTimer - 1;
    end
end


/*
 * Generate active-HIGH reset in evrClk domain
 */
(*ASYNC_REG="true"*) reg evrReset_m = 1;
(*MARK_DEBUG=DEBUG*) reg evrReset = 1;
always @(posedge evrClk) begin
    evrReset_m <= ~s_axi_aresetn;
    evrReset   <= evrReset_m;
end

/*
 * Stretch PPS strobe so it can be seen in other clock domains
 */
reg [8:0] evrPPSstretch = 0;
always @(posedge evrClk) begin
    if (evrPPSstrobe) begin
        evrPPSstretch <= ~0;
    end
    else if (evrPPSmarker) begin
        evrPPSstretch <= evrPPSstretch - 1;
    end
end
assign evrPPSmarker = evrPPSstrobe | evrPPSstretch[8];

/*
 * Instantiate hardware output drivers
 */
genvar i;
generate
for (i = 0 ; i < HARDWARE_OUTPUT_COUNT ; i = i + 1) begin : outputDriver
    wire [OUTPUT_TRIGGER_SEL_WIDTH-1:0] idx = sysOutputRavel[i]; // map physical to logical output index
    wire dbus;
    if(i<8)
        assign dbus = evrDistributedBus[i]; // TODO: allow any bit to be mapped to any output
    else
        assign dbus = 1'b0;
    ospreyEVRoutputDriver #(
        .DATA_WIDTH(32),
        .SERDES_FACTOR(SERDES_FACTOR),
        .ACTIVE_LOW_OUTPUTS(ACTIVE_LOW_OUTPUTS),
        .DEBUG(DEBUG))
      ospreyEVRoutputDriver_i (
        .sysControlUpdateToggle(sysControlUpdateToggles[idx]),
        .sysDelayCountUpdateToggle(sysDelayCountUpdateToggles[idx]),
        .sysWidthCountUpdateToggle(sysWidthCountUpdateToggles[idx]),
        .sysControlUpdateData(sysControlUpdateData),
        .sysDelayCountUpdateData(sysDelayCountUpdateData),
        .sysWidthCountUpdateData(sysWidthCountUpdateData),
        .evrClk(evrClk),
        .evrBitClk(evrBitClk),
        .evrResetSERDES(evrResetSERDES),
        .evrLinkUp(evrLinkUp),
        .evrActionIn(evrRawActions[idx]),
        .evrDbusIn(dbus),
        .evrSetIn(1'b0), // TODO: widen action RAM to allow seperate set/reset mappings
        .evrResetIn(1'b0),
        .extIn_a(hwDriverIn_a[i]),
        .evrPin(evrHardwareOutputs[i]));
end
endgenerate

/*
 * Write selected events to FIFO
 */
// Delay received data to account for action lookup latency
reg [7:0] evCode_d1 = 0, evCode_d2 = 0;
always @(posedge evrClk) begin
    evCode_d1 <= evrRxChars[15:8];
    evCode_d2 <= evCode_d1;
end

(*MARK_DEBUG=DEBUG*) wire        fifoEmpty, fifoOverflow;
(*MARK_DEBUG=DEBUG*) wire        fifoReadEnable = s_axi_rvalid &&
                                            s_axi_rready &&
                                            (rRegIndex==REG_INDEX_FIFO_EVENT) &&
                                            !fifoEmpty;
(*MARK_DEBUG=DEBUG*) wire [71:0] fifoReadData;
(*MARK_DEBUG=DEBUG*) wire [71:0] evrFifoWriteData = {evCode_d2, evrTimestamp};
reg [31:0] fifoSeconds, fifoTicks;
//  FIFO parameterized macro
xpm_fifo_async #(
    .CASCADE_HEIGHT(0),
    .CDC_SYNC_STAGES(2),
    .DOUT_RESET_VALUE("0"),
    .ECC_MODE("no_ecc"),
    .FIFO_MEMORY_TYPE("block"),
    .FIFO_READ_LATENCY(1),
    .FIFO_WRITE_DEPTH(1024),
    .FULL_RESET_VALUE(0),
    .PROG_EMPTY_THRESH(10),
    .PROG_FULL_THRESH(10),
    .RD_DATA_COUNT_WIDTH(11),
    .READ_DATA_WIDTH(72),
    .READ_MODE("fwft"),
    .RELATED_CLOCKS(0),
    .SIM_ASSERT_CHK(0),
    .USE_ADV_FEATURES("0000"),
    .WAKEUP_TIME(0),
    .WRITE_DATA_WIDTH(72),
    .WR_DATA_COUNT_WIDTH(11))
 xpm_fifo_async_inst (
    .almost_empty(),
    .almost_full(),
    .data_valid(),
    .dbiterr(),
    .dout(fifoReadData),
    .empty(fifoEmpty),
    .full(),
    .overflow(fifoOverflow),
    .prog_empty(),
    .prog_full(),
    .rd_data_count(),
    .rd_rst_busy(),
    .sbiterr(),
    .underflow(),
    .wr_ack(),
    .wr_data_count(),
    .wr_rst_busy(),
    .din(evrFifoWriteData),
    .injectdbiterr(1'b0),
    .injectsbiterr(1'b0),
    .rd_clk(s_axi_aclk),
    .rd_en(fifoReadEnable),
    .rst(evrReset),
    .sleep(1'b0),
    .wr_clk(evrClk),
    .wr_en(evrFifoWriteEnable));

/*
 * Forward time stamp to system clock domain
 */
reg evrTimestampToggle = 0;
(*ASYNC_REG="true"*) reg evrTimestampAck_m = 0;
reg evrTimestampAck = 0;
reg [63:0] evrTimestampLatch = 0;
(*ASYNC_REG="true"*) reg sysTimestampToggle_m = 0;
reg sysTimestampToggle = 0, sysTimestampAck = 0;
always @(posedge evrClk) begin
    evrTimestampAck_m <= sysTimestampAck;
    evrTimestampAck   <= evrTimestampAck_m;
    if (evrTimestampValid && (evrTimestampToggle == evrTimestampAck)) begin
        evrTimestampLatch <= evrTimestamp;
        evrTimestampToggle <= !evrTimestampToggle;
    end
end
always @(posedge s_axi_aclk) begin
    sysTimestampToggle_m <= evrTimestampToggle;
    sysTimestampToggle   <= sysTimestampToggle_m;
    if (sysTimestampToggle != sysTimestampAck) begin
        sysTimestamp <= evrTimestampLatch;
        sysTimestampAck <= !sysTimestampAck;
    end
end

////////////////////////////// AXI Registers /////////////////////////////////
/*
 * Multiplex read values
 */
reg [C_S_AXI_DATA_WIDTH-1:0] readData;
assign s_axi_rdata = readData;

wire        activeLowOutputs = ACTIVE_LOW_OUTPUTS;
wire  [3:0] serdesFactor = SERDES_FACTOR;
wire  [4:0] hwOutputCount = HARDWARE_OUTPUT_COUNT;
wire [31:0] sysStatus = {{32-1-4-5-4{1'b0}}, 
                        activeLowOutputs,
                        serdesFactor,
                        hwOutputCount,
                        fifoOverflow, !fifoEmpty, evrTimestampValid, evrLinkUp};

always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
        // TODO
    end else begin
        if (sysWriteStrobe && !wAddrIsDBUF) begin
        case (wRegIndex)
        REG_INDEX_TRIGGER_SELECT: begin
            sysOutputDriverSel <= s_axi_wdata[0+:OUTPUT_TRIGGER_SEL_WIDTH];
        end
        REG_INDEX_RAVEL: begin
            sysOutputRavel[s_axi_wdata[16+:OUTPUT_TRIGGER_SEL_WIDTH]] <= s_axi_wdata[0+:OUTPUT_TRIGGER_SEL_WIDTH];
        end
        REG_INDEX_TRIGGER_CONTROL: begin
            sysControlUpdateData <= s_axi_wdata;
            sysControlUpdateToggles[sysOutputDriverSel] <=
                                   !sysControlUpdateToggles[sysOutputDriverSel];
        end
        REG_INDEX_TRIGGER_DELAY: begin
            sysDelayCountUpdateData <= s_axi_wdata;
            sysDelayCountUpdateToggles[sysOutputDriverSel] <=
                                !sysDelayCountUpdateToggles[sysOutputDriverSel];
        end
        REG_INDEX_TRIGGER_WIDTH: begin
            sysWidthCountUpdateData <= s_axi_wdata;
            sysWidthCountUpdateToggles[sysOutputDriverSel] <=
                                !sysWidthCountUpdateToggles[sysOutputDriverSel];
        end
        default: ;
        endcase
        end

        /*
         * Readback
         */
        if(!s_axi_arvalid || !s_axi_arready) begin
        end else if (rAddrIsDBUF) begin
            readData <= distributedBufferData;
        end
        else begin
            case (rRegIndex)
            REG_INDEX_CSR:               readData <= sysStatus;
            REG_INDEX_TIMESTAMP_SECONDS: readData <= sysTimestamp[63:32];
            REG_INDEX_TIMESTAMP_TICKS:   readData <= sysTimestamp[31:0];
            REG_INDEX_ACTION_RAM:        readData <= sysActionReadback;
            REG_INDEX_FIFO_EVENT:        readData <= {!fifoEmpty, fifoOverflow,
                                                      {32-2-8{1'b0}},
                                                      fifoReadData[64+:8]};
            REG_INDEX_FIFO_SECONDS:      readData <= fifoSeconds;
            REG_INDEX_FIFO_TICKS:        readData <= fifoTicks;
            default:                     readData <= 32'hdeadbeef;
            endcase
        end

        /*
         * Side effects of reading
         */
        if (fifoReadEnable) begin
            fifoSeconds <= fifoReadData[32+:32];
            fifoTicks   <= fifoReadData[0+:32];
        end
    end
end
endmodule
`default_nettype wire
