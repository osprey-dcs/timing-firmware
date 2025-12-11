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
 */
`default_nettype none
module EVG #(
    `include "gpio.v"
    parameter DEBUG = "false"
    ) (
    input  wire DDR_REF_CLK_P,
    input  wire DDR_REF_CLK_N,
    input  wire MGTREFCLK0_116_P,
    input  wire MGTREFCLK0_116_N,
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

    input  wire PMOD2_0,
    input  wire PMOD2_1,
    output wire PMOD2_2,
    output wire PMOD2_3,
    input  wire PMOD2_4,
    input  wire PMOD2_5,
    output wire PMOD2_6,
    output wire PMOD2_7,

    input  wire PMOD1_0,  // PMOD-GPS 3DFix
    output wire PMOD1_1,  // PMOD-GPS RxD
    input  wire PMOD1_2,  // PMOD-GPS TxD
    input  wire PMOD1_3,  // PMOD-GPS PPS
    output wire PMOD1_4,
    output wire PMOD1_5,
    output wire PMOD1_6,
    output wire PMOD1_7,

    input  wire FMC1_PPS_MARKER
    );

localparam MGT_DATA_WIDTH       = 16;
localparam MGT_COMMA_ALIGN_BYTE = 1;

///////////////////////////////////////////////////////////////////////////////
// Static outputs
assign VCXO_EN = 1'b1;

///////////////////////////////////////////////////////////////////////////////
// Clocks
wire sysClk, clk20, clk125, clk200, clk500, evgClk, gtRefClkDiv2;

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
// Keep track of elapsed time
wire microsecondStrobe;
sysClkCounters #(.CLK_RATE(CFG_SYSCLK_RATE), .DEBUG("false"))
 sysClkCounters (
    .clk(sysClk),
    .usecStrobe(microsecondStrobe),
    .microsecondsSinceBoot(GPIO_IN[GPIO_IDX_MICROSECONDS_SINCE_BOOT]),
    .secondsSinceBoot(GPIO_IN[GPIO_IDX_SECONDS_SINCE_BOOT]));

///////////////////////////////////////////////////////////////////////////////
// Generate local PPS
BUFG bufClk20 (.I(CLK20_VCXO), .O(clk20));
wire localPPSmarker;
localPPS #(.DEBUG("false"))
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
wire ppsValid, clk125PPSmarker, hwPPSmarker_a;
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
    .ppsPrimary_pin(FMC1_PPS_MARKER),
    .ppsSecondary_pin(PMOD1_3),
    .ppsFromFabric(localPPSmarker),  /*FIXME! should be localPPS for EVG and EVR PPS for EVR -- how to distinguish???? */
    .hwPPSmarker_a(hwPPSmarker_a),
    .hwPPSvalid(ppsValid),
    .ppsMarker(clk125PPSmarker),
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
wire                      [CFG_MGT_COUNT-1:0] mgtRxClks;
wire                      [CFG_MGT_COUNT-1:0] mgtRxLinkUp;
wire     [(CFG_MGT_COUNT*MGT_DATA_WIDTH)-1:0] mgtRxChars;
wire [(CFG_MGT_COUNT*(MGT_DATA_WIDTH/8))-1:0] mgtRxCharIsK;
wire                     [MGT_DATA_WIDTH-1:0] evgTxChars;
wire                 [(MGT_DATA_WIDTH/8)-1:0] evgTxCharIsK;

mgtWrapper #(
    .MGT_COUNT(CFG_MGT_COUNT),
    .MGT_DATA_WIDTH(MGT_DATA_WIDTH),
    .COMMA_ALIGN_BYTE(MGT_COMMA_ALIGN_BYTE),
    .SYSCLK_RATE(CFG_SYSCLK_RATE),
    .DEBUG("false"))
  mgtWrapper_i (
    .sysClk(sysClk),
    .sysCsrStrobe(GPIO_STROBES[GPIO_IDX_MGT_CSR]),
    .sysGPIO_OUT(GPIO_OUT),
    .sysStatus(GPIO_IN[GPIO_IDX_MGT_CSR]),
    .gtRefClkP(MGTREFCLK0_116_P),
    .gtRefClkN(MGTREFCLK0_116_N),
    .gtRefClkDiv2(gtRefClkDiv2),
    .rxP(QSFP_RX_P),
    .rxN(QSFP_RX_N),
    .txP(QSFP_TX_P),
    .txN(QSFP_TX_N),
    .mgtRxClks(mgtRxClks),
    .mgtRxLinkUp(mgtRxLinkUp),
    .mgtRxChars(mgtRxChars),
    .mgtRxCharIsK(mgtRxCharIsK),
    .mgtTxClk(evgClk),
    .mgtTxChars({CFG_MGT_COUNT{evgTxChars}}),
    .mgtTxCharIsK({CFG_MGT_COUNT{evgTxCharIsK}}));

assign GPIO_IN[GPIO_IDX_LINK_STATUS] = {{32-CFG_MGT_COUNT{1'b0}}, mgtRxLinkUp};

///////////////////////////////////////////////////////////////////////////////
// Merge MPS fault status

///////////////////////////////////////////////////////////////////////////////
// Measure clocks
localparam FREQ_MON_CHANNEL_COUNT = 13;
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
    .ppsMarker_a(clk125PPSmarker),
    .evgHwInputs_a({PMOD2_1, PMOD2_4, PMOD2_0, PMOD2_5, PMOD2_1, PMOD2_4, PMOD2_0, PMOD2_5, PMOD2_1, PMOD2_4, PMOD2_0, PMOD2_5, PMOD2_1, PMOD2_4, PMOD2_0}), //FIXME: Should come from FMC1

    .evrClk(mgtRxClks[0]),
    .evrRxChars(mgtRxChars[15:0]),
    .evrRxCharIsK(mgtRxCharIsK[1:0]),
    .evrBitClk(1'b0),
    .evrLinkUp(mgtRxLinkUp[0]),
    .evrHwDriverIn(2'b00),

    .gnssPPS(hwPPSmarker_a),
    .gnssRxD(PMOD1_2),
    .gnssTxD(PMOD1_1),

    .console_rxd(FPGA_TxD),
    .console_txd(FPGA_RxD)
    );
endmodule
`default_nettype wire
