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
 * Wrapper around tinyEVG event generator
 *
 * From Axi-Lite example without additional cycle of read latency
 *        (RVALID && RREADY) is the read strobe.
 *
 * Based on the excellent tutorials by Dan Gisselquist.
 *                              https://zipcpu.com/blog/2020/03/08/easyaxil.html
 *
 * Nets with names beginning with 's_' or 'sys'
 * are in the system (AXI) clock domain.
 */

`default_nettype none

module ospreyEVG_v1_0 #(
    ////////////////////// Application-specific Parameters ///////////////////
    parameter EVGCLK_FREQUENCY   = 125000000,
    parameter TIMER_COUNT        = 2,
    parameter HW_TRIGGER_COUNT   = 8,
    parameter SEQRAM_ADDR_WIDTH  = 11,
    parameter SEQRAM_BANK_COUNT  = 2,
    parameter RX_COUNT           = 1,
    parameter INPUT_COUNT        = 15,
    parameter DEBUG              = "false",
    ////////////////////// AXI-Lite Boilerplate Parameters ///////////////////
    parameter C_S_AXI_FREQ_HZ    = 100000000,
    parameter C_S_AXI_ADDR_WIDTH = 7,
    parameter C_S_AXI_DATA_WIDTH = 32
    ) (
    ////////////////////// Application-specific Ports ///////////////////
    input  wire                     evgClk,
    input  wire                     ppsMarker_a,
    input  wire   [INPUT_COUNT-1:0] hwInputs_a,
    output wire              [15:0] evgTxChars,
    output wire               [1:0] evgTxCharIsK,
    input  wire                     sampleClk,
    input  wire                     sampleClkX4,
    input  wire      [RX_COUNT-1:0] evgRxClks,
    input  wire [(RX_COUNT*16)-1:0] evgRxChars,
    input  wire  [(RX_COUNT*2)-1:0] evgRxCharIsK,

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

(*MARK_DEBUG="true"*)
    input  wire                          s_axi_awvalid,
    output wire                          s_axi_awready,
(*MARK_DEBUG="true"*)
    input  wire                    [2:0] s_axi_awprot,
(*MARK_DEBUG="true"*)
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
(*MARK_DEBUG="true"*)
    input  wire                          s_axi_wvalid,
(*MARK_DEBUG="true"*)
    output reg                           s_axi_wready = 0,
(*MARK_DEBUG="true"*)
    input  wire                    [3:0] s_axi_wstrb,
(*MARK_DEBUG="true"*)
    input  wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata,
(*MARK_DEBUG="true"*)
    output reg                           s_axi_bvalid = 0,
(*MARK_DEBUG="true"*)
    input  wire                          s_axi_bready,
(*MARK_DEBUG="true"*)
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
(*MARK_DEBUG="true"*)
reg [WRITE_WAIT_STATE_COUNTER_WIDTH-1:0] writeWaitStateCounter;
wire writeWaitStateCounterDone =
                        writeWaitStateCounter[WRITE_WAIT_STATE_COUNTER_WIDTH-1];
reg writeTransactionActive = 0;

assign s_axi_awready = s_axi_wready;
(*MARK_DEBUG="true"*)
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
//////////////////////// End of AXI-Lite Boilerplate ////////////////////////

//////////////////////////////////////////////////////////////////////////////
localparam DBUS_WIDTH     = 8;
localparam INPUTSEL_WIDTH = $clog2(INPUT_COUNT+1);

/*
 * Sanity checks
 */
if ((TIMER_COUNT < 2) || (TIMER_COUNT > 8)) begin
    error_TIMER_COUNT_OUT_OF_RANGE();
end
if ((HW_TRIGGER_COUNT < 2) || (HW_TRIGGER_COUNT > 8)) begin
    error_HW_TRIGGER_COUNT_OUT_OF_RANGE();
end
if ((SEQRAM_BANK_COUNT < 2) || (SEQRAM_BANK_COUNT > 8)) begin
    error_SEQRAM_BANK_COUNT_OUT_OF_RANGE();
end
if ((SEQRAM_ADDR_WIDTH < 8) || (SEQRAM_ADDR_WIDTH > 12)) begin
    error_SEQRAM_ADDR_WIDTH_OUT_OF_RANGE();
end

/*
 * One for table-driven event (highest-priority), one for each
 * timer-driven event, two for each hardware trigger (rising/falling),
 * one for software-driven event (lowest-priority).
 */
localparam EVCHAIN_LENGTH = 1 + TIMER_COUNT + (2 * HW_TRIGGER_COUNT) + 1;
genvar i, j;

//
// AXI component (system clock domain)
//

// Parse addresses
localparam REGSEL_WIDTH = 5;
wire [REGSEL_WIDTH-1:0] s_wRegIndex = s_axi_awaddr[2+:REGSEL_WIDTH];
wire [REGSEL_WIDTH-1:0] s_rRegIndex = s_axi_araddr[2+:REGSEL_WIDTH];
localparam REG_IDX_CSR               = 5'd0;
localparam REG_IDX_CONFIG            = 5'd1;
localparam REG_IDX_CLK_RATE          = 5'd2;
localparam REG_IDX_SECONDS           = 5'd3;
localparam REG_IDX_HEARTBEAT_DIVISOR = 5'd4;
localparam REG_IDX_HW_TRIGGER_CONFIG = 5'd5;
localparam REG_IDX_SW_EVENT          = 5'd6;
localparam REG_IDX_SEQ_ADDR_CODE     = 5'd7;
localparam REG_IDX_SEQ_GAP           = 5'd8;
localparam REG_IDX_HW_TRIGGER_MAP    = 5'd9;
localparam REG_IDX_DBUS_MAP          = 5'd10;
localparam REG_IDX_TIMER_CSR         = 5'd11;
localparam REG_IDX_LATENCY_CSR       = 5'd12;
localparam REG_IDX_TIMER_CONFIG_BASE = 5'd16;

reg sysSetSecondsToggle = 0;
reg [31:0] sysPosixSeconds;

reg sysSetHeartbeatDivisorToggle = 0;

if ((TIMER_COUNT < 2) || (TIMER_COUNT > 8)) begin
    Invalid_TIMER_COUNT();
end
reg sysTimerControlToggle = 0;
reg [TIMER_COUNT-1:0] sysTimerCodeToggle = 0, sysTimerInitValToggle = 0;
localparam TIMERSEL_WIDTH = $clog2(TIMER_COUNT);
wire timerInitValSel = s_axi_awaddr[2];
wire [TIMERSEL_WIDTH-1:0] timerSel = s_axi_awaddr[3+:TIMERSEL_WIDTH];
wire [(2*TIMER_COUNT)-1:0] timerStatus;

reg [(2*HW_TRIGGER_COUNT)-1:0] sysHwUpdateToggle = 0;
localparam HWSEL_WIDTH = $clog2(2*HW_TRIGGER_COUNT);
wire [HWSEL_WIDTH-1:0] hwSel = s_axi_wdata[8+:HWSEL_WIDTH];

reg sysSwTriggerToggle = 0;
reg sysHwTriggerMapUpdateToggle = 0, sysDbusMapUpdateToggle = 0;
reg [(HW_TRIGGER_COUNT*INPUTSEL_WIDTH)-1:0] hwTriggerMap = 0;
reg [(DBUS_WIDTH*INPUTSEL_WIDTH)-1:0] dbusMap = 0;

reg [31:0] sysReadData;
assign s_axi_rdata = sysReadData;

/*
 * Forward references to some EVG clock values.
 * No need for fancy clock-crossing logic since the
 * processor knows that races are possible.
 */
(*MARK_DEBUG=DEBUG*) reg evgPPSvalid = 0;
(*MARK_DEBUG=DEBUG*) reg evgSecondsValid = 0;
(*MARK_DEBUG=DEBUG*) reg evgPPStoggle = 0;
(*MARK_DEBUG=DEBUG*) reg [31:0] evgPosixSeconds = 0;
(*MARK_DEBUG=DEBUG*) reg [31:0] evgClkStatus;
wire [31:0] seqStatus, seqAddrCodeRbk, seqGapRbk, latencyStatus;

// Configuration
wire [3:0] seqAddrWidth = SEQRAM_ADDR_WIDTH;
wire [3:0] bankCount    = SEQRAM_BANK_COUNT;
wire [3:0] timerCount   = TIMER_COUNT;
wire [3:0] triggerCount = HW_TRIGGER_COUNT;
wire [3:0] rxCount      = RX_COUNT;
wire [31:0] sysConfig = { {32-(5*4){1'b0}},
                          rxCount,
                          seqAddrWidth,
                          bankCount,
                          timerCount,
                          triggerCount };
// Status
wire [31:0] sysStatus = { {32-20-4{1'b0}},
                          seqStatus[19:0],
                          1'b0, evgPPStoggle, evgSecondsValid, evgPPSvalid };

always @(posedge s_axi_aclk)
begin
    if (!s_axi_aresetn) begin
    end
    else begin
        /*
         * Control (write) operations
         */
        if (sysWriteStrobe) begin
        if (s_wRegIndex & REG_IDX_TIMER_CONFIG_BASE) begin
            if (timerInitValSel) begin
               sysTimerInitValToggle[timerSel] <=
                                               !sysTimerInitValToggle[timerSel];
            end
            else begin
               sysTimerCodeToggle[timerSel]<=!sysTimerCodeToggle[timerSel];
            end
        end
        else case (s_wRegIndex)
        REG_IDX_SECONDS: begin
            sysPosixSeconds <= s_axi_wdata;
            sysSetSecondsToggle <= !sysSetSecondsToggle;
        end
        REG_IDX_HEARTBEAT_DIVISOR: begin
            sysSetHeartbeatDivisorToggle <= !sysSetHeartbeatDivisorToggle;
        end
        REG_IDX_HW_TRIGGER_CONFIG: begin
            sysHwUpdateToggle[hwSel] <= !sysHwUpdateToggle[hwSel];
        end
        REG_IDX_SW_EVENT: begin
            sysSwTriggerToggle <= !sysSwTriggerToggle;
        end
        REG_IDX_HW_TRIGGER_MAP: begin
            sysHwTriggerMapUpdateToggle <= !sysHwTriggerMapUpdateToggle;
        end
        REG_IDX_TIMER_CSR: begin
            sysTimerControlToggle <= !sysTimerControlToggle;
        end
        REG_IDX_DBUS_MAP: begin
            sysDbusMapUpdateToggle <= !sysDbusMapUpdateToggle;
        end
        default: ;
        endcase
        end

        /*
         * Readback operations
         */
        if (s_axi_arvalid && s_axi_arready) begin
            case (s_rRegIndex)
            REG_IDX_CSR:            sysReadData <= sysStatus;
            REG_IDX_CONFIG:         sysReadData <= sysConfig;
            REG_IDX_CLK_RATE:       sysReadData <= evgClkStatus;
            REG_IDX_SECONDS:        sysReadData <= evgPosixSeconds;
            REG_IDX_SEQ_ADDR_CODE:  sysReadData <= seqAddrCodeRbk;
            REG_IDX_SEQ_GAP:        sysReadData <= seqGapRbk;
            REG_IDX_LATENCY_CSR:    sysReadData <= latencyStatus;
            REG_IDX_HW_TRIGGER_MAP: sysReadData <=
                   {{32-(HW_TRIGGER_COUNT*INPUTSEL_WIDTH){1'b0}}, hwTriggerMap};
            REG_IDX_TIMER_CSR: sysReadData <=
                                      {{32-(2*TIMER_COUNT){1'b0}}, timerStatus};
            REG_IDX_DBUS_MAP:       sysReadData <=
                              {{32-(DBUS_WIDTH*INPUTSEL_WIDTH){1'b0}}, dbusMap};
            default:                sysReadData <= 0;
            endcase
        end
    end
end

/*
 * Measure round-trip latency
 */
ospreyEVGlatencyCheck #(
    .RX_COUNT(RX_COUNT),
    .EVENT_CODE_BYTE(1),
    .MGT_DATA_WIDTH(16),
    .DEBUG(DEBUG))
  ospreyEVGlatencyCheck_i (
    .sysClk(s_axi_aclk),
    .sysCsrStrobe(sysWriteStrobe && (s_wRegIndex == REG_IDX_LATENCY_CSR)),
    .sysGPIO_OUT(s_axi_wdata),
    .sysStatus(latencyStatus),
    .sampleClk(sampleClk),
    .sampleClkX4(sampleClkX4),
    .mgtRxClks(evgRxClks),
    .mgtRxChars(evgRxChars),
    .mgtRxCharIsK(evgRxCharIsK),
    .mgtTxClk(evgClk),
    .mgtTxChars(evgTxChars),
    .mgtTxCharIsK(evgTxCharIsK));

//////////////////////////////////////////////////////////////////////////////
//
// Event generator (MGT transmitter) clock domain
// The write wait-state code ensures that s_axi_wdata is stable when used.
//

/*
 * Synchronize and map hardware inputs
 */
(*ASYNC_REG="true"*) reg hwTriggerMapUpdateToggle_m = 0;
reg hwTriggerMapUpdateToggle = 0, hwTriggerMapUpdateToggle_d;
(*ASYNC_REG="true"*) reg dbusMapUpdateToggle_m = 0;
reg dbusMapUpdateToggle = 0, dbusMapUpdateToggle_d;
(*ASYNC_REG="true"*) reg [INPUT_COUNT-1:0] hwInputs_m = 0;
reg [INPUT_COUNT-1:0] hwInputs = 0;
always @(posedge evgClk) begin
    hwInputs_m <= hwInputs_a;
    hwInputs   <= hwInputs_m;

    dbusMapUpdateToggle_m <= sysDbusMapUpdateToggle;
    dbusMapUpdateToggle   <= dbusMapUpdateToggle_m;
    dbusMapUpdateToggle_d <= dbusMapUpdateToggle;
    if (dbusMapUpdateToggle != dbusMapUpdateToggle_d) begin
        dbusMap <= s_axi_wdata[(DBUS_WIDTH*INPUTSEL_WIDTH)-1:0];
    end

    hwTriggerMapUpdateToggle_m <= sysHwTriggerMapUpdateToggle;
    hwTriggerMapUpdateToggle   <= hwTriggerMapUpdateToggle_m;
    hwTriggerMapUpdateToggle_d <= hwTriggerMapUpdateToggle;
    if (hwTriggerMapUpdateToggle != hwTriggerMapUpdateToggle_d) begin
        hwTriggerMap <= s_axi_wdata[(HW_TRIGGER_COUNT*INPUTSEL_WIDTH)-1:0];
    end
end
wire [INPUT_COUNT:0] evgHwIn = {hwInputs, 1'b0};

/*
 * PPS handling
 */
(*ASYNC_REG="true"*) reg evgPPSmarker_m = 0;
(*MARK_DEBUG=DEBUG*) reg evgPPSmarker = 0, evgPPSmarker_d = 0;
wire evgPPSrising = (evgPPSmarker && !evgPPSmarker_d);

// Validate PPS
localparam PPS_TOO_FAST_RELOAD = ((EVGCLK_FREQUENCY / 100) * 99) - 1;
localparam PPS_TOO_SLOW_RELOAD = ((EVGCLK_FREQUENCY / 100) * 101) - 1;
localparam PPS_TOO_FAST_WIDTH = $clog2(PPS_TOO_FAST_RELOAD+1) + 1;
localparam PPS_TOO_SLOW_WIDTH = $clog2(PPS_TOO_FAST_RELOAD+1) + 1;
(*MARK_DEBUG=DEBUG*) reg [PPS_TOO_FAST_WIDTH-1:0] evgPPStooFastCounter =
                                                            PPS_TOO_FAST_RELOAD;
wire evgPPStooFast = !evgPPStooFastCounter[PPS_TOO_FAST_WIDTH-1];
(*MARK_DEBUG=DEBUG*) reg [PPS_TOO_SLOW_WIDTH-1:0] evgPPStooSlowCounter =
                                                            PPS_TOO_SLOW_RELOAD;
wire evgPPStooSlow = evgPPStooSlowCounter[PPS_TOO_SLOW_WIDTH-1];
reg [PPS_TOO_SLOW_WIDTH-1:0] evgClkRateCounter = 0;

always @(posedge evgClk) begin
    evgPPSmarker_m <= ppsMarker_a;
    evgPPSmarker   <= evgPPSmarker_m;
    evgPPSmarker_d <= evgPPSmarker;
    if (evgPPSrising) begin
        evgPPStooFastCounter <= PPS_TOO_FAST_RELOAD;
        evgPPStooSlowCounter <= PPS_TOO_SLOW_RELOAD;
        evgClkRateCounter <= 1;
        if (evgPPStooFast || evgPPStooSlow) begin
            evgPPSvalid <= 0;
        end
        else begin
            evgPPSvalid <= 1;
            evgPPStoggle <= !evgPPStoggle;
            evgClkStatus <= {{32-PPS_TOO_SLOW_WIDTH{1'b0}},
                             evgClkRateCounter};
        end
    end
    else begin
        evgClkRateCounter <= evgClkRateCounter + 1;
        if (evgPPStooFast) begin
            evgPPStooFastCounter <= evgPPStooFastCounter - 1;
        end
        if (evgPPStooSlow) begin
            evgPPSvalid <= 0;
        end
        else begin
            evgPPStooSlowCounter <= evgPPStooSlowCounter - 1;
        end
    end
end

/*
 * Time-of-day updates in evgClk domain
 */
(*ASYNC_REG="true"*) reg evgSetSecondsToggle_m = 0;
(*MARK_DEBUG=DEBUG*) reg evgSetSecondsToggle = 0, evgSetSecondsToggle_d = 0;
always @(posedge evgClk) begin
    evgSetSecondsToggle_m <= sysSetSecondsToggle;
    evgSetSecondsToggle   <= evgSetSecondsToggle_m;
    evgSetSecondsToggle_d <= evgSetSecondsToggle;
    if (evgPPSvalid) begin
        if (evgSetSecondsToggle != evgSetSecondsToggle_d) begin
            evgSecondsValid <= 1;
        end
    end
    else begin
        evgSecondsValid <= 0;
    end
end

/*
 * Heartbeat generation
 */
(*ASYNC_REG="true"*) reg evgSetHeartbeatDivisorToggle_m = 0;
reg evgSetHeartbeatDivisorToggle = 0, evgSetHeartbeatDivisorToggle_d = 0;
reg evgHeartbeatEnable;
reg [31:0] evgHeartbeatLoad = 0;
reg [32:0] evgHeartbeatCounter = 0;
(*MARK_DEBUG=DEBUG*) wire evgHeartbeatRequest = evgHeartbeatCounter[32];
always @(posedge evgClk) begin
    evgSetHeartbeatDivisorToggle_m <= sysSetHeartbeatDivisorToggle;
    evgSetHeartbeatDivisorToggle   <= evgSetHeartbeatDivisorToggle_m;
    evgSetHeartbeatDivisorToggle_d <= evgSetHeartbeatDivisorToggle;
    if (evgSetHeartbeatDivisorToggle != evgSetHeartbeatDivisorToggle_d) begin
        evgHeartbeatLoad <= s_axi_wdata - 2;
        if (s_axi_wdata < 1024) begin
            evgHeartbeatEnable <= 0;
        end
        else begin
            evgHeartbeatEnable <= 1;
        end
    end
    if (evgHeartbeatEnable) begin
        if (evgHeartbeatRequest) begin
            evgHeartbeatCounter <= { 1'b0, evgHeartbeatLoad };
        end
        else begin
            evgHeartbeatCounter <= evgHeartbeatCounter - 1;
        end
    end
    else begin
        evgHeartbeatCounter <= 0;
    end
end

/*
 * Table-driven events
 */
wire                        sequencerEventStrobe;
wire                  [7:0] sequencerEventCode;
wire [HW_TRIGGER_COUNT-1:0] evgHwTriggerRising, evgHwTriggerFalling;
ospreyEVGsequencer #(
    .HW_TRIGGER_COUNT(HW_TRIGGER_COUNT),
    .SEQUENCE_CAPACITY(1<<SEQRAM_ADDR_WIDTH),
    .BANK_COUNT(SEQRAM_BANK_COUNT),
    .DPRAM_TYPE("auto"),
    .GAP_WIDTH(32),
    .DB_WIDTH(32),
    .EVCODE_WIDTH(8),
    .DEBUG(DEBUG))
  ospreyEVGsequencer_i (
    .sysClk(s_axi_aclk),
    .sysCsrStrobe(sysWriteStrobe && (s_wRegIndex==REG_IDX_CSR)),
    .sysAddressCodeStrobe(sysWriteStrobe&&(s_wRegIndex==REG_IDX_SEQ_ADDR_CODE)),
    .sysGapStrobe(sysWriteStrobe && (s_wRegIndex==REG_IDX_SEQ_GAP)),
    .sysGPIO_OUT(s_axi_wdata),
    .sysStatus(seqStatus),
    .sysAddressCodeRbk(seqAddrCodeRbk),
    .sysGapRbk(seqGapRbk),
    .evgClk(evgClk),
    .evgHwTriggerRising(evgHwTriggerRising),
    .evgHwTriggerFalling(evgHwTriggerFalling),
    .evgCodeTDATA(sequencerEventCode),
    .evgCodeTVALID(sequencerEventStrobe));

/*
 * Timer-initated events
 */
localparam TIMER_CMD_NOP    = 2'b00;
localparam TIMER_CMD_STOP   = 2'b01;
localparam TIMER_CMD_RESUME = 2'b10;
localparam TIMER_CMD_START  = 2'b11;
(*ASYNC_REG="true"*) reg timerControlToggle_m = 0;
(*MARK_DEBUG=DEBUG*) reg timerControlToggle = 0, timerControlToggle_d = 0;
always @(posedge evgClk) begin
    timerControlToggle_m <= sysTimerControlToggle;
    timerControlToggle   <= timerControlToggle_m;
    timerControlToggle_d <= timerControlToggle;
end
(*MARK_DEBUG=DEBUG*) reg  [TIMER_COUNT-1:0] timerTriggerEnables = 0;
(*MARK_DEBUG=DEBUG*) wire [TIMER_COUNT-1:0] timerTriggerStrobes;
(*MARK_DEBUG=DEBUG*) reg  [(TIMER_COUNT*8)-1:0] timerEventCodes = 0;
generate
for (i = 0 ; i < TIMER_COUNT ; i = i + 1) begin : timerRequester
    (*MARK_DEBUG=DEBUG*) wire[1:0] timerCmd = s_axi_wdata[i*2+:2];
    (*ASYNC_REG="true"*) reg timerCodeToggle_m = 0;
    (*MARK_DEBUG=DEBUG*) reg timerCodeToggle = 0, timerCodeToggle_d;
    (*ASYNC_REG="true"*) reg timerInitValToggle_m = 0;
    (*MARK_DEBUG=DEBUG*) reg timerInitValToggle = 0, timerInitValToggle_d;
    reg [31:0] timerInitVal = ~0;
    (*MARK_DEBUG=DEBUG*) reg [32:0] timer = 0;
    wire timerDone = timer[32];
    always @(posedge evgClk) begin
        timerCodeToggle_m <= sysTimerCodeToggle[i];
        timerCodeToggle   <= timerCodeToggle_m;
        timerCodeToggle_d <= timerCodeToggle;
        if (timerCodeToggle != timerCodeToggle_d) begin
            timerEventCodes[i*8+:8] <= s_axi_wdata[7:0];
        end
        timerInitValToggle_m <= sysTimerInitValToggle[i];
        timerInitValToggle   <= timerInitValToggle_m;
        timerInitValToggle_d <= timerInitValToggle;
        if (timerInitValToggle != timerInitValToggle_d) begin
            timerInitVal <= s_axi_wdata;
            if (!timerTriggerEnables[i]) begin
                // Set timer so an initial 'resume' behaves expectedly.
                timer <= {1'b0, s_axi_wdata};
            end
        end
        if ((timerControlToggle != timerControlToggle_d)
         && (timerCmd != TIMER_CMD_NOP)) begin
            case (timerCmd)
            TIMER_CMD_STOP: begin
                timerTriggerEnables[i] <= 0;
                if (timerDone) begin
                    timer <= {1'b0, timerInitVal};
                end
            end
            TIMER_CMD_RESUME: begin
                timerTriggerEnables[i] <= 1;
            end
            TIMER_CMD_START: begin
                timerTriggerEnables[i] <= 1;
                timer <= {1'b0, timerInitVal};
            end
            endcase
        end
        else if (timerTriggerEnables[i]) begin
            if (timerDone) begin
                timer <= {1'b0, timerInitVal};
            end
            else begin
                timer <= timer - 1;
            end
        end
    end
    assign timerTriggerStrobes[i] = timerDone;
    assign timerStatus[i*2+:2] = {timerTriggerEnables[i], 1'b0};
end
endgenerate

/*
 * Hardware-initated events
 */
(*MARK_DEBUG=DEBUG*) reg [(2*HW_TRIGGER_COUNT)-1:0] hwTriggerEnables = 0;
(*MARK_DEBUG=DEBUG*) reg [(2*HW_TRIGGER_COUNT)-1:0] hwTriggerStrobes = 0;
(*MARK_DEBUG=DEBUG*) reg [(2*HW_TRIGGER_COUNT*8)-1:0] hwEventCodes = 0;
generate
for (i = 0 ; i < HW_TRIGGER_COUNT ; i = i + 1) begin : hwRequester
    (*ASYNC_REG="true"*) reg hwTrigger_m = 0;
    reg hwTrigger = 0, hwTrigger_d = 0;
    always @(posedge evgClk) begin
        hwTrigger   <= evgHwIn[hwTriggerMap[i*INPUTSEL_WIDTH+:INPUTSEL_WIDTH]];
        hwTrigger_d <= hwTrigger;
        hwTriggerStrobes[(i*2)+0] <= hwTrigger && !hwTrigger_d;
        hwTriggerStrobes[(i*2)+1] <= !hwTrigger && hwTrigger_d;
    end
    assign evgHwTriggerRising[i] = hwTriggerStrobes[(i*2)+0];
    assign evgHwTriggerFalling[i] = hwTriggerStrobes[(i*2)+1];
    for (j = 0 ; j < 2 ; j = j + 1) begin : hwEdge
        (*ASYNC_REG="true"*) reg hwUpdateToggle_m = 0;
        reg hwUpdateToggle = 0, hwUpdateToggle_d;
        always @(posedge evgClk) begin
            hwUpdateToggle_m <= sysHwUpdateToggle[(i*2)+j];
            hwUpdateToggle   <= hwUpdateToggle_m;
            hwUpdateToggle_d <= hwUpdateToggle;
            if (hwUpdateToggle != hwUpdateToggle_d) begin
                hwTriggerEnables[(i*2)+j] <= (s_axi_wdata[7:0] != 0);
                hwEventCodes[((i*2)+j)*8+:8] <= s_axi_wdata[7:0];
            end
        end
    end
end
endgenerate

/*
 * Software-initiated events
 */
(*ASYNC_REG="true"*) reg swTriggerToggle_m = 0;
reg swTriggerToggle = 0, swTriggerToggle_d = 0;
reg swTriggerStrobe = 0;
reg [7:0] swEventCode = 8'b0;
always @(posedge evgClk) begin
    swTriggerToggle_m <= sysSwTriggerToggle;
    swTriggerToggle   <= swTriggerToggle_m;
    swTriggerToggle_d <= swTriggerToggle;
    if (swTriggerToggle != swTriggerToggle_d) begin
        swEventCode <= s_axi_wdata[7:0];
        swTriggerStrobe <= 1;
    end
    else begin
        swTriggerStrobe <= 0;
    end
end

/*
 * Priority-encoded chain of event requesters.
 * Table-driven and software-driven event sources are always enabled.
 */
wire [EVCHAIN_LENGTH-1:0]  enables = { 1'b1,
                                       hwTriggerEnables,
                                       timerTriggerEnables,
                                       1'b1 };
wire [EVCHAIN_LENGTH-1:0] triggers = { swTriggerStrobe,
                                       hwTriggerStrobes,
                                       timerTriggerStrobes,
                                       sequencerEventStrobe };
wire [(EVCHAIN_LENGTH*8)-1:0] evCodes = { swEventCode,
                                          hwEventCodes,
                                          timerEventCodes,
                                          sequencerEventCode };
wire           [EVCHAIN_LENGTH:0] pendingChain;
wire [((EVCHAIN_LENGTH+1)*8)-1:0] eventChain;

// Head of chains
assign pendingChain[0] = 0;
assign eventChain[0+:8] = 0;

// Extract value to be sent to transmitter
(*MARK_DEBUG=DEBUG*) wire eventRequest = pendingChain[EVCHAIN_LENGTH];
(*MARK_DEBUG=DEBUG*) wire [7:0] eventCode = eventChain[EVCHAIN_LENGTH*8+:8];

/*
 * Instantiate the event requesters
 * The first ospreyEVGeventSource instantiated (corresponding to the
 * least-signficant entries in the 'enables', 'trigger' and 'evCodes
 * nets) has the highest priority.
 */
generate
for (i = 0 ; i < EVCHAIN_LENGTH ; i = i + 1) begin : eventRequester
  ospreyEVGeventSource ospreyEVGeventSource_i (
    .clk(evgClk),
    .enable(enables[i]),
    .triggerStrobe(triggers[i]),
    .code(evCodes[i*8+:8]),
    .evPendingIn(pendingChain[i]),
    .evCodeIn(eventChain[i*8+:8]),
    .evPendingOut(pendingChain[i+1]),
    .evCodeOut(eventChain[(i+1)*8+:8]));
end
endgenerate

/*
 * Distributed bus
 * FIXME: Should the map update have proper clock-crossing?
 */
generate
reg [7:0] evgDistributedBus;
for (i = 0 ; i < DBUS_WIDTH ; i = i + 1) begin : dBus
  always @(posedge evgClk) begin
    evgDistributedBus[i] <= evgHwIn[dbusMap[i*INPUTSEL_WIDTH+:INPUTSEL_WIDTH]];
  end
end
endgenerate

/*
 * Instantiate the tiny event generator that does the real work
 */
localparam DISTRIBUTED_BUFFER_ADDRESS_WIDTH = 10;
tinyEVG #(
    .DISTRIBUTED_BUFFER_ADDRESS_WIDTH(DISTRIBUTED_BUFFER_ADDRESS_WIDTH),
    .DEBUG(DEBUG))
  tinyEVG_i (
    .evgTxClk(evgClk),
    .evgTxWord(evgTxChars),
    .evgTxIsK(evgTxCharIsK),
    .eventCode(eventCode),
    .eventStrobe(eventRequest),
    .heartbeatRequest(evgHeartbeatRequest),
    .ppsStrobe(evgPPSrising),
    .secondsStrobe(evgSetSecondsToggle != evgSetSecondsToggle_d),
    .seconds(sysPosixSeconds),
    .distributedBus(evgDistributedBus),
    .sysClk(1'b0),
    .sysWriteStrobe(1'b0),
    .sysAddress({DISTRIBUTED_BUFFER_ADDRESS_WIDTH{1'b0}}),
    .sysData(8'h00),
    .sysSendStrobe(1'b0),
    .sysBusy());

endmodule

/*
 * Single event source.
 * These are linked together in one big priority-encoded list.
 */
module ospreyEVGeventSource (
    input  wire          clk,
    input  wire          enable,
    input  wire          triggerStrobe,
    input  wire    [7:0] code,
    input  wire          evPendingIn,
    input  wire    [7:0] evCodeIn,
    output wire          evPendingOut,
    output wire    [7:0] evCodeOut);

reg       myRequest = 0;
reg [7:0] myEvent;

assign evPendingOut = evPendingIn || myRequest;
assign evCodeOut = evPendingIn ? evCodeIn : myEvent;

always @(posedge clk) begin
    if (enable) begin
        if (triggerStrobe) begin
            myRequest <= 1;
            myEvent <= code;
        end
        else if (!evPendingIn) begin
            myRequest <= 0;
        end
    end
    else begin
        myRequest <= 0;
    end
end
endmodule
`default_nettype wire
