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

`default_nettype none
module ospreyEVR_v1_0 #(
    ////////////////////// Application-specific Parameters ///////////////////
    parameter DISTRIBUTED_BUFFER_ADDR_WIDTH = 10,
    parameter HARDWARE_OUTPUT_COUNT         = 4,
    parameter SERDES_FACTOR                 = 8,
    parameter ACTION_STROBES_WIDTH          = 16,
    parameter ENABLE_TRISTATE_CONTROL       = 0,
    parameter TRISTATE_INIT_STATE           = 0,
    parameter TRISTATE_RESET_STATE          = 0,
    parameter ACTIVE_LOW_OUTPUTS            = 0,
    parameter DEBUG                         = "false",
    ////////////////////// AXI-Lite Boilerplate Parameters ///////////////////
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

    /*
     * Hardware outputs -- must connect directly to pin.
     */
    inout  wire [HARDWARE_OUTPUT_COUNT-1:0] evrHardwareOutputs,
    input  wire [HARDWARE_OUTPUT_COUNT-1:0] hwDriverIn_a,

    /*
     * Output tri-state control.
     * Used only if ENABLE_TRISTATE_CONTROL is true.
     */
    input  wire [HARDWARE_OUTPUT_COUNT-1:0] evrTriStateIn,
    output wire [HARDWARE_OUTPUT_COUNT-1:0] evrTriStateOut,

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
 * Read side -- Ensure address remains stable during cycle
 */
reg  [C_S_AXI_ADDR_WIDTH-1:0] raddrLatch;
wire [C_S_AXI_ADDR_WIDTH-1:0] raddr = s_axi_arready ? s_axi_araddr : raddrLatch;
always @(posedge s_axi_aclk)
begin
    if (!s_axi_aresetn) begin
        s_axi_arready <= 1;
        s_axi_rvalid <= 0;
    end
    else if (s_axi_arready) begin
        raddrLatch <= s_axi_araddr;
        if (s_axi_arvalid) begin
            s_axi_arready <= 0;
        end
    end
    else begin
        if (s_axi_rvalid) begin
            if (s_axi_rready) begin
                s_axi_rvalid <= 0;
                s_axi_arready <= 1;
            end
        end
        else begin
            s_axi_rvalid <= 1;
        end
    end
end

/*
 * Write side
 */
assign s_axi_awready = s_axi_wready;
always @(posedge s_axi_aclk)
begin
    if (!s_axi_aresetn) begin
        s_axi_wready <= 0;
    end
    else begin
        s_axi_wready <= !s_axi_wready && s_axi_awvalid && s_axi_wvalid &&
                                                (!s_axi_bvalid || s_axi_bready);
    end
    if (!s_axi_aresetn) begin
        s_axi_bvalid <= 0;
    end
    else if (s_axi_wready) begin
        s_axi_bvalid <= 1;
    end
    else if (s_axi_bready) begin
        s_axi_bvalid <= 0;
    end
end
//////////////////////// End of AXI-Lite Boilerplate ////////////////////////

/*
 * Sanity checks
 */
if ((DISTRIBUTED_BUFFER_ADDR_WIDTH < 9)
 || (DISTRIBUTED_BUFFER_ADDR_WIDTH >= C_S_AXI_ADDR_WIDTH)) begin
    invalid_DISTRIBUTED_BUFFER_ADDR_WIDTH();
end
if ((HARDWARE_OUTPUT_COUNT < 2) || (HARDWARE_OUTPUT_COUNT > 12)) begin
  invalid_HARDWARE_OUTPUT_COUNT();
end
if (HARDWARE_OUTPUT_COUNT > ACTION_STROBES_WIDTH) begin
  HARDWARE_OUTPUT_COUNT_must_not_exceed_ACTION_STROBES_WIDTH();
end
if ((SERDES_FACTOR!=1) && (SERDES_FACTOR!=4)
 && (SERDES_FACTOR!=6) && (SERDES_FACTOR!=8)) begin
  invalid_SERDES_FACTOR();
end
if ((ACTION_STROBES_WIDTH < 12) || (ACTION_STROBES_WIDTH > 22)) begin
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

localparam REG_INDEX_CSR               = 0;
localparam REG_INDEX_TIMESTAMP_SECONDS = 2;
localparam REG_INDEX_TIMESTAMP_TICKS   = 3;
localparam REG_INDEX_ACTION_RAM        = 4;
localparam REG_INDEX_FIFO_EVENT        = 5;
localparam REG_INDEX_FIFO_SECONDS      = 6;
localparam REG_INDEX_FIFO_TICKS        = 7;
localparam REG_INDEX_TRIGGER_SELECT    = 8;
localparam REG_INDEX_TRIGGER_CONTROL   = 9;
localparam REG_INDEX_TRIGGER_DELAY     = 10;
localparam REG_INDEX_TRIGGER_WIDTH     = 11;

/*
 * Hardware output control registers
 */
localparam OUTPUT_TRIGGER_SEL_WIDTH = $clog2(HARDWARE_OUTPUT_COUNT);
reg [OUTPUT_TRIGGER_SEL_WIDTH-1:0] sysOutputDriverSel = 0;
reg [HARDWARE_OUTPUT_COUNT-1:0] sysControlUpdateToggles = 0,
                                sysDelayCountUpdateToggles = 0,
                                sysWidthCountUpdateToggles = 0;
reg [C_S_AXI_DATA_WIDTH-1:0] sysControlUpdateData = 0,
                             sysDelayCountUpdateData = 0,
                             sysWidthCountUpdateData = 0;

/*
 * Distributed buffer readout
 */
wire [31:0] distributedBufferData = 0;

/*
 * Instantiate core EVR
 */
wire coreWriteStrobe = (s_axi_wready && !wAddrIsDBUF &&
                                           (wRegIndex == REG_INDEX_ACTION_RAM));
wire [(ACTION_STROBES_WIDTH+2)-1:0] evrRawActions;
assign evrActionStrobes  = evrRawActions[0+:ACTION_STROBES_WIDTH];
wire evrInterruptRequest = evrRawActions[ACTION_STROBES_WIDTH];
wire evrFifoWriteEnable  = evrRawActions[ACTION_STROBES_WIDTH+1];
smallEVR #(
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
    .sysActionAddress(s_axi_wdata[7:0]),
    .sysActionData(s_axi_wdata[8+:ACTION_STROBES_WIDTH+2]));

/*
 * Startup sequencing
 */
reg evrResetSERDES = 1;
always @(posedge evrClk) begin
    evrResetSERDES <= 0;
end


/*
 * Generate active-HIGH resets in evrClk domain
 */
(*ASYNC_REG="true"*) reg evrReset_m = 1;
(*MARK_DEBUG=DEBUG*) reg evrReset = 1;
wire EnableTriState = ENABLE_TRISTATE_CONTROL;
(*ASYNC_REG="true"*) reg [HARDWARE_OUTPUT_COUNT-1:0] evrTriState_m =
                            {HARDWARE_OUTPUT_COUNT{ENABLE_TRISTATE_CONTROL[0]}};
reg [HARDWARE_OUTPUT_COUNT-1:0] evrTriState =
                            {HARDWARE_OUTPUT_COUNT{ENABLE_TRISTATE_CONTROL[0]}};
always @(posedge evrClk) begin
    evrReset_m <= ~s_axi_aresetn;
    evrReset   <= evrReset_m;
    evrTriState_m <= evrTriStateIn;
    evrTriState   <= evrTriState_m;
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
    ospreyEVRoutputDriver #(
        .DATA_WIDTH(32),
        .SERDES_FACTOR(SERDES_FACTOR),
        .ENABLE_TRISTATE_CONTROL(ENABLE_TRISTATE_CONTROL),
        .TRISTATE_INIT_STATE(TRISTATE_INIT_STATE[i]),
        .TRISTATE_RESET_STATE(TRISTATE_RESET_STATE[i]),
        .ACTIVE_LOW_OUTPUTS(ACTIVE_LOW_OUTPUTS),
        .DEBUG(DEBUG))
      ospreyEVRoutputDriver_i (
        .sysControlUpdateToggle(sysControlUpdateToggles[i]),
        .sysDelayCountUpdateToggle(sysDelayCountUpdateToggles[i]),
        .sysWidthCountUpdateToggle(sysWidthCountUpdateToggles[i]),
        .sysControlUpdateData(sysControlUpdateData),
        .sysDelayCountUpdateData(sysDelayCountUpdateData),
        .sysWidthCountUpdateData(sysWidthCountUpdateData),
        .evrClk(evrClk),
        .evrBitClk(evrBitClk),
        .evrResetSERDES(evrResetSERDES),
        .evrLinkUp(evrLinkUp),
        .evrActionIn(evrRawActions[i]),
        .evrDbusIn((i<8) ? evrDistributedBus[i] : 1'b0),
        .evrSetIn(evrRawActions[i]),
        .evrResetIn(evrRawActions[i+1]),
        .extIn_a(hwDriverIn_a[i]),
        .evrTriStateIn(evrTriState[i]),
        .evrTriStateOut(evrTriStateOut[i]),
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
reg [C_S_AXI_DATA_WIDTH-1:0] regMux, readData;
reg [C_S_AXI_DATA_WIDTH-1:0] controlReg;
assign s_axi_rdata = readData;

wire        activeLowOutputs = ACTIVE_LOW_OUTPUTS;
wire  [3:0] serdesFactor = SERDES_FACTOR;
wire  [4:0] hwOutputCount = HARDWARE_OUTPUT_COUNT;
wire [31:0] sysStatus = {{32-HARDWARE_OUTPUT_COUNT-1-4-5-4{1'b0}}, 
                        evrTriStateIn,
                        activeLowOutputs,
                        serdesFactor,
                        hwOutputCount,
                        fifoOverflow, !fifoEmpty, evrTimestampValid, evrLinkUp};

always @(posedge s_axi_aclk) begin
    /*
     * Control
     */
    if (s_axi_wready && !wAddrIsDBUF) begin
        case (wRegIndex)
        REG_INDEX_TRIGGER_SELECT: begin
            sysOutputDriverSel <= s_axi_wdata[0+:OUTPUT_TRIGGER_SEL_WIDTH];
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
    if (rAddrIsDBUF) begin
        readData <= distributedBufferData;
    end
    else begin
        case (rRegIndex)
        REG_INDEX_CSR:               readData <= sysStatus;
        REG_INDEX_TIMESTAMP_SECONDS: readData <= sysTimestamp[63:32];
        REG_INDEX_TIMESTAMP_TICKS:   readData <= sysTimestamp[31:0];
        REG_INDEX_FIFO_EVENT:        readData <= {!fifoEmpty, fifoOverflow,
                                                  {32-2-8{1'b0}},
                                                  fifoReadData[64+:8]};
        REG_INDEX_FIFO_SECONDS:      readData <= fifoSeconds;
        REG_INDEX_FIFO_TICKS:        readData <= fifoTicks;
        default:                     readData <= 0;
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
endmodule
`default_nettype wire
