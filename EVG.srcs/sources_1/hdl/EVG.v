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
 * Top level module
 * For development the 'USE_PMOD_GPS' definition should be uncommented.
 */
//`define USE_PMOD_GPS

`default_nettype none
module EVG #(
    `include "gpio.v"
    parameter DEBUG = "false"
    ) (
    input  wire DDR_REF_CLK_P,
    input  wire DDR_REF_CLK_N,
    input  wire MGTREFCLK0_116_P,
    input  wire MGTREFCLK0_116_N,
    input  wire FMC1_CLK0_M2C_P,
    input  wire FMC1_CLK0_M2C_N,
    input  wire FMC1_CLK1_M2C_P,
    input  wire FMC1_CLK1_M2C_N,
    input  wire CLK20_VCXO,
    output wire VCXO_EN,

    output wire BOOT_CS_B,
    output wire BOOT_MOSI,
    input  wire BOOT_MISO,

    input  wire FPGA_TxD,
    output wire FPGA_RxD,

    inout  wire I2C_FPGA_SCL,
    inout  wire I2C_FPGA_SDA,
    output wire I2C_FPGA_SW_RSTn,

    output wire WR_DAC_SCLK_T,
    output wire WR_DAC_DIN_T,
    output wire WR_DAC1_SYNC_Tn,
    output wire WR_DAC2_SYNC_Tn,

    input  wire FPGA_SCLK,
    input  wire FPGA_CSB,
    input  wire FPGA_MOSI,
    output wire FPGA_MISO,

    input  wire       RGMII_RX_CLK,
    input  wire       RGMII_RX_CTRL,
    input  wire [3:0] RGMII_RXD,
    output wire       RGMII_TX_CLK,
    output wire       RGMII_TX_CTRL,
    output wire [3:0] RGMII_TXD,
    output wire       RGMII_PHY_RESET_n,

    input  wire [CFG_MGT_COUNT-1:0] QSFP_RX_P,
    input  wire [CFG_MGT_COUNT-1:0] QSFP_RX_N,
    output wire [CFG_MGT_COUNT-1:0] QSFP_TX_P,
    output wire [CFG_MGT_COUNT-1:0] QSFP_TX_N,

    input  wire PMOD1_0,
    input  wire PMOD1_1,
    output wire PMOD1_2,
    output wire PMOD1_3,
    input  wire PMOD1_4,
    input  wire PMOD1_5,
    output wire PMOD1_6,
    output wire PMOD1_7,  // Optional PPS out

`ifdef USE_PMOD_GPS
    input  wire PMOD2_0,  // PMOD-GPS 3DFix
    output wire PMOD2_1,  // PMOD-GPS RxD
    input  wire PMOD2_2,  // PMOD-GPS TxD
    input  wire PMOD2_3,  // PMOD-GPS PPS
`else
    input  wire PMOD2_0,
    input  wire PMOD2_1,
    output wire PMOD2_2,
    output wire PMOD2_3,
`endif
    input  wire PMOD2_4,
    input  wire PMOD2_5,
    output wire PMOD2_6,
    output wire PMOD2_7,

    output wire LD16,
    output wire LD17,

    input  wire        FMC1_PPS,
    input  wire [15:1] FMC1_DIN,
    output wire        FMC1_LMK01801_CLK,
    output wire        FMC1_LMK01801_LE,
    output wire        FMC1_LMK01801_DATA,
    output wire        FMC1_ADS7253_CLK,
    output wire        FMC1_ADS7253_CSB,
    output wire        FMC1_ADS7253_DIN,
    input  wire        FMC1_ADS7253_DOUTA,
    input  wire        FMC1_ADS7253_DOUTB
    );

localparam MGT_DATA_WIDTH       = 16;
localparam MGT_COMMA_ALIGN_BYTE = 1;
localparam TIMESTAMP_WIDTH      = 64;

///////////////////////////////////////////////////////////////////////////////
// Static outputs
assign VCXO_EN = 1'b1;
assign LD17 = 1'b0;

///////////////////////////////////////////////////////////////////////////////
// PMOD I/O routing
// For development a PPS marker from a PMOD-GPS module drives a PMOD-TTL
// output which is externally looped back to the RF-IN PPS input.

wire [7:0] pmodOut;
wire ppsSecondary_out;

assign PMOD2_7 = pmodOut[7];
assign PMOD2_6 = pmodOut[5];
assign PMOD1_3 = pmodOut[2];
assign PMOD1_6 = pmodOut[1];
assign PMOD1_2 = pmodOut[0];

`ifdef USE_PMOD_GPS
wire ppsSecondary = PMOD2_3;
assign PMOD1_7 = ~ppsSecondary_out;
assign PMOD2_1 = 1'b1;
`else
wire ppsSecondary = 1'b0;
assign PMOD2_3 = pmodOut[6];
assign PMOD2_2 = pmodOut[4];
assign PMOD1_7 = pmodOut[3];
`endif

wire [7:0] pmodIn = { ~PMOD2_5, ~PMOD2_1, ~PMOD2_4, ~PMOD2_0,
                      ~PMOD1_5, ~PMOD1_1, ~PMOD1_4, ~PMOD1_0 };

///////////////////////////////////////////////////////////////////////////////
// Clocks
wire sysClk, clk20, clk125, clk200, clk500, evgClk, gtRefClkDiv2;

wire clkFMC1_M2C0, clkFMC1_M2C1;
IBUFGDS FMC1_M2C0_IB(.I(FMC1_CLK0_M2C_P),.IB(FMC1_CLK0_M2C_N),.O(clkFMC1_M2C0));
IBUFGDS FMC1_M2C1_IB(.I(FMC1_CLK1_M2C_P),.IB(FMC1_CLK1_M2C_N),.O(clkFMC1_M2C1));

///////////////////////////////////////////////////////////////////////////////
// General-purpose I/O register glue
wire [31:0] GPIO_OUT;
wire [GPIO_IDX_COUNT-1:0] GPIO_STROBES;
wire [31:0] GPIO_IN [0:GPIO_IDX_COUNT-1];
wire [(GPIO_IDX_COUNT*32)-1:0] GPIO_IN_FLATTENED;
genvar i;
generate
for (i = 0 ; i < GPIO_IDX_COUNT ; i = i + 1) begin
    assign GPIO_IN_FLATTENED[i*32+:32] = GPIO_IN[i];
end
endgenerate

`include "firmwareBuildDate.v"
assign GPIO_IN[GPIO_IDX_FIRMWARE_DATE] = FIRMWARE_BUILD_DATE;

///////////////////////////////////////////////////////////////////////////////
// Ospref RF-IN FMC module
ospreyRFIN #(
    .DEBUG("false"))
  ospreyRFIN (
    .sysClk(sysClk),
    .csrStrobe(GPIO_STROBES[GPIO_IDX_RFIN_CONTROL]),
    .GPIO_OUT(GPIO_OUT),
    .readback(GPIO_IN[GPIO_IDX_RFIN_CONTROL]),
    .RFIN_LMK01801_CLK(FMC1_LMK01801_CLK),
    .RFIN_LMK01801_LE(FMC1_LMK01801_LE),
    .RFIN_LMK01801_DATA(FMC1_LMK01801_DATA),
    .RFIN_ADS7253_CLK(FMC1_ADS7253_CLK),
    .RFIN_ADS7253_CSB(FMC1_ADS7253_CSB),
    .RFIN_ADS7253_DIN(FMC1_ADS7253_DIN),
    .RFIN_ADS7253_DOUTA(FMC1_ADS7253_DOUTA),
    .RFIN_ADS7253_DOUTB(FMC1_ADS7253_DOUTB));

///////////////////////////////////////////////////////////////////////////////
// Keep track of elapsed time
wire microsecondStrobe;
sysClkCounters #(.CLK_RATE(CFG_SYSCLK_RATE), .DEBUG("false"))
 sysClkCounters (
    .clk(sysClk),
    .usecStrobe(microsecondStrobe),
    .microsecondsSinceBoot(GPIO_IN[GPIO_IDX_MICROSECONDS_SINCE_BOOT]),
    .secondsSinceBoot(GPIO_IN[GPIO_IDX_SECONDS_SINCE_BOOT]));

///////////////////////////////////////////////////////////////////////////////
// I/O marshalling
// FMC1, if present, is an RF-input.
// PMOD1, if present, is a PMOD-IO (for production) or a PMOD-GPS (for testing).
// PMOD2, if present, is a PMOD-IO.

wire [14:0] evgHwInputs;
wire [31:0] ioSelectStatus;
wire isEVG = ioSelectStatus[0];
assign GPIO_IN[GPIO_IDX_IO_SELECT] = ioSelectStatus;
wire ppsPrimary_out;

ioSelect #(.DEBUG("false"))
  ioSelect (
    .sysClk(sysClk),
    .sysCsrStrobe(GPIO_STROBES[GPIO_IDX_IO_SELECT]),
    .sysGPIO_OUT(GPIO_OUT),
    .sysStatus(GPIO_IN[GPIO_IDX_IO_SELECT]),
    .evgHwInputs(evgHwInputs),
    .fmcInputs(FMC1_DIN),
    .pmodInputs(pmodIn));

assign GPIO_IN[GPIO_IDX_PMOD_FMC_MONITOR] = {8'b0, pmodIn,
                                             FMC1_DIN, ppsPrimary_out};


///////////////////////////////////////////////////////////////////////////////
// Generate local PPS
BUFG bufClk20 (.I(CLK20_VCXO), .O(clk20));
wire localPPSmarker;
localPPS #(
    .SYSCLK_RATE(CFG_SYSCLK_RATE),
    .DEBUG("false"))
  localPPS_i (
    .sysClk(sysClk),
    .sysCsrStrobe(GPIO_STROBES[GPIO_IDX_LOCAL_PPS_CSR]),
    .sysGPIO_OUT(GPIO_OUT),
    .sysStatus(GPIO_IN[GPIO_IDX_LOCAL_PPS_CSR]),
    .clk20(clk20),
    .localPPSmarker(localPPSmarker));

///////////////////////////////////////////////////////////////////////////////
// Lock clock to PPS marker
// DAC1 adjusts the 125 MHz MGT reference, DDR reference, and system clocks.
// DAC2 adjusts the 20 MHz system clock.
wire ppsValid, evgPPSmarker, hwPPSmarker_a, evrPPSmarker;
marbleClockSync #(
    .DEBUG("false"))
  marbleClockSync (
    .sysClk(sysClk),
    .sysCsrStrobe(GPIO_STROBES[GPIO_IDX_MARBLE_VCXO_PLL_CSR]),
    .sysGPIO_OUT(GPIO_OUT),
    .sysStatus(GPIO_IN[GPIO_IDX_MARBLE_VCXO_PLL_CSR]),
    .sysAuxStatus(GPIO_IN[GPIO_IDX_MARBLE_VCXO_PLL_AUX]),
    .sysHwInterval(GPIO_IN[GPIO_IDX_MARBLE_VCXO_HW_PPS]),
    .clk125(clk125),
    .clk500(clk500),
    .ppsPrimary_pin(FMC1_PPS),
    .ppsSecondary_pin(ppsSecondary),
    .ppsFromFabric(isEVG ? localPPSmarker : evrPPSmarker),
    .hwPPSmarker_a(hwPPSmarker_a),
    .ppsPrimary_out(ppsPrimary_out),
    .ppsSecondary_out(ppsSecondary_out),
    .hwPPSvalid(ppsValid),
    .ppsMarker(evgPPSmarker),
    .ppsToggle(),
    .SPI_CLK(WR_DAC_SCLK_T),
    .SPI_SYNCn({WR_DAC2_SYNC_Tn, WR_DAC1_SYNC_Tn}),
    .SPI_SDI(WR_DAC_DIN_T));

//////////////////////////////////////////////////////////////////////////////
// Drive boot flash SCLK from block design FLASH_SPI_sclk after initialization.
wire BOOT_SCLK, startupEOS;
STARTUPE2 aspiClkPin
     (.CLK(1'b0),
      .GSR(1'b0),
      .GTS(1'b0),
      .KEYCLEARB(1'b1),
      .PACK(1'b0),
      .PREQ(),
      .USRCCLKO(BOOT_SCLK),
      .USRCCLKTS(1'b0),
      .USRDONEO(1'b0),
      .USRDONETS(1'b1),
      .CFGCLK(),
      .CFGMCLK(),
      .EOS(startupEOS));

///////////////////////////////////////////////////////////////////////////////
// FPGA I2C
wire i2c_fpga_scl_o, i2c_fpga_scl_i, i2c_fpga_scl_t;
wire i2c_fpga_sda_o, i2c_fpga_sda_i, i2c_fpga_sda_t;
IOBUF i2c_fpga_scl_iobuf (.I(i2c_fpga_scl_o),
                          .O(i2c_fpga_scl_i),
                          .T(i2c_fpga_scl_t),
                          .IO(I2C_FPGA_SCL));
IOBUF i2c_fpga_sda_iobuf (.I(i2c_fpga_sda_o),
                          .O(i2c_fpga_sda_i),
                          .T(i2c_fpga_sda_t),
                          .IO(I2C_FPGA_SDA));

///////////////////////////////////////////////////////////////////////////////
// Microcontroller I/O
mmcIO #(.DEBUG("false"))
  mmcIO (
    .clk(sysClk),
    .csrStrobe(GPIO_STROBES[GPIO_IDX_MMC_IO]),
    .GPIO_OUT(GPIO_OUT),
    .status(GPIO_IN[GPIO_IDX_MMC_IO]),
    .MMC_SCLK(FPGA_SCLK),
    .MMC_CSB(FPGA_CSB),
    .MMC_MOSI(FPGA_MOSI),
    .MMC_MISO(FPGA_MISO));

///////////////////////////////////////////////////////////////////////////////
// Multi-gigabit transceivers
// Machine protection data transfer.
localparam MGT_CTYPE_WIDTH = (MGT_DATA_WIDTH+7) / 8;
wire                  [MGT_DATA_WIDTH-1:0] evgTxChars;
wire                 [MGT_CTYPE_WIDTH-1:0] evgTxCharIsK;
wire                   [CFG_MGT_COUNT-1:0] mgtRxClks;
wire                   [CFG_MGT_COUNT-1:0] mgtRxLinkUp;
wire  [(CFG_MGT_COUNT*MGT_DATA_WIDTH)-1:0] mgtRxChars;
wire [(CFG_MGT_COUNT*MGT_CTYPE_WIDTH)-1:0] mgtRxCharIsK;
wire            [CFG_MPS_OUTPUT_COUNT-1:0] mpsTripped;

fiberLinks #(
    .MGT_COUNT(CFG_MGT_COUNT),
    .MGT_DATA_WIDTH(MGT_DATA_WIDTH),
    .MPS_OUTPUT_COUNT(CFG_MPS_OUTPUT_COUNT),
    .DEBUG("false"),
    .DEBUG_MGT("false"),
    .DEBUG_EVR("false"),
    .DEBUG_EVF("false"),
    .DEBUG_EVG("false"),
    .DEBUG_EVS("false"),
    .DEBUG_MPS("false"))
  fiberLinks (
    .sysClk(sysClk),
    .sysMgtCsrStrobe(GPIO_STROBES[GPIO_IDX_MGT_CSR]),
    .sysGPIO_OUT(GPIO_OUT),
    .sysMgtStatus(GPIO_IN[GPIO_IDX_MGT_CSR]),
    .sysLinkStatus(GPIO_IN[GPIO_IDX_LINK_STATUS]),
    .isEVG(isEVG),
    .mpsTripped_a(mpsTripped),
    .mgtRxClks(mgtRxClks),
    .mgtRxLinkUp(mgtRxLinkUp),
    .mgtRxChars(mgtRxChars),
    .mgtRxCharIsK(mgtRxCharIsK),
    .mgtTxClk(evgClk),
    .evgTxChars(evgTxChars),
    .evgTxCharIsK(evgTxCharIsK),
    .gtRefClkP(MGTREFCLK0_116_P),
    .gtRefClkN(MGTREFCLK0_116_N),
    .gtRefClkDiv2(gtRefClkDiv2),
    .rxP(QSFP_RX_P),
    .rxN(QSFP_RX_N),
    .txP(QSFP_TX_P),
    .txN(QSFP_TX_N));

// FIXME: Need some glitch-free way to drive PMOD outputs with either MPS trips or EVR hardware outputs.

///////////////////////////////////////////////////////////////////////////////
// Machine protection operations
wire [TIMESTAMP_WIDTH-1:0] evrTimestamp;
mps #(
    .EVR_MPS_CLEAR_EVENT(CFG_EVR_MPS_CLEAR_EVENT),
    .MGT_COUNT(CFG_MGT_COUNT),
    .MGT_DATA_WIDTH(MGT_DATA_WIDTH),
    .MGT_CTYPE_WIDTH(MGT_CTYPE_WIDTH),
    .MPS_INPUT_COUNT(CFG_MPS_INPUT_COUNT),
    .MPS_OUTPUT_COUNT(CFG_MPS_OUTPUT_COUNT),
    .TIMESTAMP_WIDTH(TIMESTAMP_WIDTH),
    .DEBUG("true"))
  mps_i (
    .sysClk(sysClk),
    .sysLocalCsrStrobe(GPIO_STROBES[GPIO_IDX_MPS_LOCAL_CSR]),
    .sysLocalDataStrobe(GPIO_STROBES[GPIO_IDX_MPS_LOCAL_DATA]),
    .sysMergeCsrStrobe(GPIO_STROBES[GPIO_IDX_MPS_MERGE_CSR]),
    .sysGPIO_OUT(GPIO_OUT),
    .sysLocalStatus(GPIO_IN[GPIO_IDX_MPS_LOCAL_CSR]),
    .sysLocalData(GPIO_IN[GPIO_IDX_MPS_LOCAL_DATA]),
    .sysMergeStatus(GPIO_IN[GPIO_IDX_MPS_MERGE_CSR]),
    .mgtRxClks(mgtRxClks),
    .mgtRxChars(mgtRxChars),
    .mgtRxCharIsK(mgtRxCharIsK),
    .mgtRxLinkUp(mgtRxLinkUp),
    .evrTimestamp(evrTimestamp),
    .mpsInputStates_a(evgHwInputs[CFG_MPS_INPUT_COUNT-1:0]),
    .mgtTxClk(evgClk),
    .mpsTripped(mpsTripped));

///////////////////////////////////////////////////////////////////////////////
// Measure clocks
localparam FREQ_MON_CHANNEL_COUNT = 15;
wire [29:0] measuredFrequency;
wire measuredUsingInteralAcqMarker;
reg [$clog2(FREQ_MON_CHANNEL_COUNT)-1:0] frequencyChannelSelect = 0;
frequencyCounters #(
    .CLOCKS_PER_ACQUISITION(CFG_SYSCLK_RATE),
    .CHANNEL_COUNT(FREQ_MON_CHANNEL_COUNT))
  frequencyCounters (
    .clk(sysClk),
    .measuredClocks({ mgtRxClks[7],
                      mgtRxClks[6],
                      mgtRxClks[5],
                      mgtRxClks[4],
                      mgtRxClks[3],
                      mgtRxClks[2],
                      mgtRxClks[1],
                      mgtRxClks[0],
                      evgClk,
                      clkFMC1_M2C1,
                      clkFMC1_M2C0,
                      clk20,
                      clk200,
                      gtRefClkDiv2,
                      sysClk }),
    .acqMarker_a(hwPPSmarker_a),
    .useInternalAcqMarker(measuredUsingInteralAcqMarker),
    .channelSelect(frequencyChannelSelect),
    .frequency(measuredFrequency));
always @(posedge sysClk) begin
    if (GPIO_STROBES[GPIO_IDX_FREQUENCY_COUNTERS]) begin
        frequencyChannelSelect <= GPIO_OUT[$clog2(FREQ_MON_CHANNEL_COUNT)-1:0];
    end
end
assign GPIO_IN[GPIO_IDX_FREQUENCY_COUNTERS] = { measuredUsingInteralAcqMarker,
                                                      1'b0, measuredFrequency };

///////////////////////////////////////////////////////////////////////////////
// Delay data from PHY
wire [3:0] rgmiiDataDelayed;
wire       rgmiiCtrlDelayed;
ethernetRxDelay ethernetRxDelay_inst (
    .refClk200(clk200),
    .rst(!RGMII_PHY_RESET_n),
    .phyDataIn({RGMII_RX_CTRL, RGMII_RXD}),
    .phyDataOut({rgmiiCtrlDelayed, rgmiiDataDelayed}));

///////////////////////////////////////////////////////////////////////////////
// Block design

bd bd_i (
    .DDR_REF_clk_p(DDR_REF_CLK_P),
    .DDR_REF_clk_n(DDR_REF_CLK_N),
    .sysReset_n(1'b1),
    .startupEOS(startupEOS),
    .sysClk(sysClk),
    .clk20(clk20),
    .clk125(clk125),
    .clk500(clk500),
    .clk200(clk200),

    .FLASH_SPI_sclk(BOOT_SCLK),
    .FLASH_SPI_csb(BOOT_CS_B),
    .FLASH_SPI_si(BOOT_MISO),
    .FLASH_SPI_so(BOOT_MOSI),

    .i2c_fpga_scl_i(i2c_fpga_scl_i),
    .i2c_fpga_scl_o(i2c_fpga_scl_o),
    .i2c_fpga_scl_t(i2c_fpga_scl_t),
    .i2c_fpga_sda_i(i2c_fpga_sda_i),
    .i2c_fpga_sda_o(i2c_fpga_sda_o),
    .i2c_fpga_sda_t(i2c_fpga_sda_t),
    .i2c_fpga_gpo(I2C_FPGA_SW_RSTn),

    .RGMII_rxc(RGMII_RX_CLK),
    .RGMII_rd(rgmiiDataDelayed),
    .RGMII_rx_ctl(rgmiiCtrlDelayed),
    .RGMII_txc(RGMII_TX_CLK),
    .RGMII_td(RGMII_TXD),
    .RGMII_tx_ctl(RGMII_TX_CTRL),
    .phy_reset_n(RGMII_PHY_RESET_n),
    .fastTxUDP_tdata(8'h00),
    .fastTxUDP_tlast(1'b0),
    .fastTxUDP_tready(),
    .fastTxUDP_tvalid(1'b0),

    .GPIO_OUT(GPIO_OUT),
    .GPIO_STROBES(GPIO_STROBES),
    .GPIO_IN(GPIO_IN_FLATTENED),

    .evgClk(evgClk),
    .evgTxChars(evgTxChars),
    .evgTxCharIsK(evgTxCharIsK),
    .evgRxClks(mgtRxClks),
    .evgRxChars(mgtRxChars),
    .evgRxCharIsK(mgtRxCharIsK),
    .ppsMarker_a(evgPPSmarker),
    .evgHwInputs_a(evgHwInputs),

    .evrClk(mgtRxClks[0]),
    .evrRxChars(mgtRxChars[MGT_DATA_WIDTH-1:0]),
    .evrRxCharIsK(mgtRxChars[MGT_CTYPE_WIDTH-1:0]),
    .evrPPSmarker(evrPPSmarker),
    .evrLinkUp(mgtRxLinkUp[0]),
    .evrHwDriverIn(8'h00),
    .evrHardwareOutputs(pmodOut),
    .evrTimestamp(evrTimestamp),

    .console_rxd(FPGA_TxD),
    .console_txd(FPGA_RxD)
    );
endmodule
`default_nettype wire
