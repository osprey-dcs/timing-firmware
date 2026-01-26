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
 * Measure event link round-trip latency
 */
`timescale 1ns/10ps
`default_nettype none
module ospreyEVGlatencyCheck #(
    parameter RX_COUNT        = 1,
    parameter EVENT_CODE_BYTE = 1,
    parameter MGT_DATA_WIDTH  = 16,
    parameter LATENCY_WIDTH   = 16,
    parameter DEBUG           = "false"
    ) (
    input  wire        sysClk,
    input  wire        sysCsrStrobe,
    input  wire [31:0] sysGPIO_OUT,
    output wire [31:0] sysStatus,

    input wire sampleClk,
    input wire sampleClkX4,

    input  wire                      [RX_COUNT-1:0] mgtRxClks,
    input  wire     [(RX_COUNT*MGT_DATA_WIDTH)-1:0] mgtRxChars,
    input  wire [(RX_COUNT*(MGT_DATA_WIDTH/8))-1:0] mgtRxCharIsK,

    input  wire                          mgtTxClk,
    input  wire     [MGT_DATA_WIDTH-1:0] mgtTxChars,
    input  wire [(MGT_DATA_WIDTH/8)-1:0] mgtTxCharIsK,

    output wire [(RX_COUNT*LATENCY_WIDTH)-1:0] latencies);

localparam TIMEOUT_US      = 7;
localparam SERDES_FACTOR   = 8;
localparam COUNTER_WIDTH   = $clog2(TIMEOUT_US * 1000) + 1;
localparam FILTER_L2_ALPHA = 6;
localparam FILTER_WIDTH = COUNTER_WIDTH - 1 + FILTER_L2_ALPHA;
localparam RESULT_WIDTH = COUNTER_WIDTH - 1 + 3;

localparam EVCODE_PPS  = 8'h7D;
localparam EVCODE_ZERO = 8'h70;
localparam EVCODE_ONE  = 8'h71;

///////////////////////////////////////////////////////////////////////////////
// System clock domain

// In receiver clock domains, but readout code knows to read until stable.
wire [FILTER_WIDTH-1:0] filters [0:RX_COUNT-1];

// Select readout channel
localparam MUXSEL_WIDTH = (RX_COUNT == 1) ? 1 : $clog2(RX_COUNT);
(*MARK_DEBUG=DEBUG*) reg [MUXSEL_WIDTH-1:0] sysMuxSel = 0;
wire [FILTER_WIDTH-1:0] filterMux = filters[sysMuxSel];
(*MARK_DEBUG=DEBUG*) reg [RESULT_WIDTH-1:0] sysLatency = 0;
always @(posedge sysClk) begin
    if (sysCsrStrobe) begin
        sysMuxSel <= sysGPIO_OUT[0+:MUXSEL_WIDTH];
    end
    sysLatency <= filterMux[FILTER_WIDTH-1-:RESULT_WIDTH];
end
assign sysStatus = {{24-RESULT_WIDTH{1'b0}}, sysLatency,
                    {8-MUXSEL_WIDTH{1'b0}}, sysMuxSel};

///////////////////////////////////////////////////////////////////////////////
// Transmitter clock domain
/*
 * Indicate the start of a measurement cycle
 */
(*MARK_DEBUG=DEBUG*) wire [7:0] evTxCode = mgtTxChars[EVENT_CODE_BYTE*8+:8];
(*MARK_DEBUG=DEBUG*) wire       evTxCodeIsK = mgtTxCharIsK[EVENT_CODE_BYTE];
(*MARK_DEBUG=DEBUG*) reg mgtTxStart = 0;
always @(posedge mgtTxClk) begin
    if (!evTxCodeIsK && ((evTxCode == EVCODE_PPS)
                      || (evTxCode == EVCODE_ZERO)
                      || (evTxCode == EVCODE_ONE))) begin
        mgtTxStart <= 1;
    end
    else begin
        mgtTxStart <= 0;
    end
end

///////////////////////////////////////////////////////////////////////////////
// Sampling clock domain
/*
 * Detect leading edge of start indicator
 */
(*MARK_DEBUG=DEBUG*) wire smpStartStrobe;
(*MARK_DEBUG=DEBUG*) wire [$clog2(SERDES_FACTOR)-1:0] smpStartLeadingZeroCount;
ospreyEVGlatencyFindRising #(.SERDES_FACTOR(SERDES_FACTOR))
  ospreyEVGlatencyFindRisingStart (
    .sampleClk(sampleClk),
    .sampleClkX4(sampleClkX4),
    .I(mgtTxStart),
    .startStrobe(smpStartStrobe),
    .leadingZeroCount(smpStartLeadingZeroCount));

///////////////////////////////////////////////////////////////////////////////
// Receiver and sampling clock domains
genvar i;
generate
for (i = 0 ; i < RX_COUNT ; i = i + 1) begin
    /*
     * Detect end of measurement cycle
     */
    (*MARK_DEBUG=DEBUG*) wire [7:0] evRxCode =
                          mgtRxChars[(i*MGT_DATA_WIDTH)+(EVENT_CODE_BYTE*8)+:8];
    (*MARK_DEBUG=DEBUG*) wire       evRxCodeIsK =
                          mgtRxCharIsK[(i*(MGT_DATA_WIDTH/8))+EVENT_CODE_BYTE];
    (*MARK_DEBUG=DEBUG*) reg mgtRxStart = 0;
    always @(posedge mgtRxClks[i]) begin
        if (!evRxCodeIsK && ((evRxCode == EVCODE_PPS)
                          || (evRxCode == EVCODE_ZERO)
                          || (evRxCode == EVCODE_ONE))) begin
            mgtRxStart <= 1;
        end
        else begin
            mgtRxStart <= 0;
        end
    end

    /*
     * Detect leading edge of done indicator
     */
    (*MARK_DEBUG=DEBUG*)wire smpDoneStrobe;
    (*MARK_DEBUG=DEBUG*)wire[$clog2(SERDES_FACTOR)-1:0]smpDoneLeadingZeroCount;
    ospreyEVGlatencyFindRising #(
        .SERDES_FACTOR(SERDES_FACTOR),
        .DEBUG(DEBUG))
      ospreyEVGlatencyFindRisingDone (
        .sampleClk(sampleClk),
        .sampleClkX4(sampleClkX4),
        .I(mgtRxStart),
        .startStrobe(smpDoneStrobe),
        .leadingZeroCount(smpDoneLeadingZeroCount));

    (*MARK_DEBUG=DEBUG*) reg active = 0, active_d = 0;
    (*MARK_DEBUG=DEBUG*) reg [COUNTER_WIDTH-1:0] counter = 0;
    (*MARK_DEBUG=DEBUG*) wire overflow = counter[COUNTER_WIDTH-1];
    (*MARK_DEBUG=DEBUG*) reg wasValid = 0;

    (*MARK_DEBUG=DEBUG*) reg [FILTER_WIDTH-1:0] filter = 0;
    assign filters[i] = filter;
    assign latencies[i*LATENCY_WIDTH+:LATENCY_WIDTH] =
                                          filter[FILTER_WIDTH-1-:LATENCY_WIDTH];

    always @(posedge sampleClk) begin
        /*
         * Measure start->done interval
         */
        if (active) begin
            if (overflow) begin
                active <= 0;
            end
            else if (smpDoneStrobe) begin
                counter <= counter + smpDoneLeadingZeroCount;
                active <= 0;
            end
            else begin
                counter <= counter + SERDES_FACTOR;
            end
        end
        else if (smpStartStrobe) begin
            counter <= SERDES_FACTOR - smpStartLeadingZeroCount;
            active <= 1;
        end

        /*
         * Low-pass filter result
         */
        active_d <= active;
        if (!active && active_d) begin
            wasValid <= !overflow;
            if (overflow) begin
                filter <= {FILTER_WIDTH{1'b1}};
            end
            else if (wasValid) begin
                filter <= filter - (filter >> FILTER_L2_ALPHA) +
                          {{FILTER_L2_ALPHA{1'b0}}, counter[COUNTER_WIDTH-2:0]};
            end
            else begin
                filter <= {counter[COUNTER_WIDTH-2:0], {FILTER_L2_ALPHA{1'b0}}};
            end
        end
    end
end
endgenerate

endmodule

// Detect rising edge and count leading zeros
module ospreyEVGlatencyFindRising #(
    parameter SERDES_FACTOR = 8,
    parameter DEBUG         = "false"
    ) (
    input  wire sampleClk,
    input  wire sampleClkX4,
    input  wire                            I,
    output reg                             startStrobe,
    output reg [$clog2(SERDES_FACTOR)-1:0] leadingZeroCount);

// Instantiate the fine-timing edge measurement
wire [SERDES_FACTOR-1:0] txFine;
ospreyEVGlatencyCheckSERDES
  ospreyEVGlatencyCheckSERDES_i (
    .sampleClk(sampleClk),
    .sampleClkX4(sampleClkX4),
    .I(I),
    .O(txFine));

// Detect leading edge and find it's position
(*MARK_DEBUG=DEBUG*)(*ASYNC_REG="true"*) reg [SERDES_FACTOR-1:0] txFine_r;
wire start = |txFine_r;
reg start_d = 0;
integer i, brk;
always @(posedge sampleClk) begin
    txFine_r <= txFine;
    start_d <= start;
    if (start && !start_d) begin
        brk = 0;
        for (i = 0 ; (i < SERDES_FACTOR) && !brk ; i = i + 1) begin
            if (txFine_r[SERDES_FACTOR-1-i]) begin
                leadingZeroCount <= i;
                brk = 1;
            end
        end
        startStrobe <= 1;
    end
    else begin
        startStrobe <= 0;
    end
end
endmodule

// Fine timing measurement
module ospreyEVGlatencyCheckSERDES (
    input  wire       sampleClk,
    input  wire       sampleClkX4,
    input  wire       I,
    output wire [7:0] O);

`ifdef SIMULATION
wire sampleClkX4_d;
assign #0.01 sampleClkX4_d = sampleClkX4;
reg [7:0] shiftReg, sample;
always @(posedge sampleClkX4 or negedge sampleClkX4) begin
    shiftReg <= {shiftReg[6:0], I};
end
always @(posedge sampleClk) begin
    sample <= shiftReg;
end
assign O = sample;
`else
wire I_d;

//
// An IDELAY is required to drive the ISERDES from fabric.
//
IDELAYE2 #(
    .CINVCTRL_SEL("FALSE"),   // Enable dynamic clock inversion (FALSE, TRUE)
    .DELAY_SRC("DATAIN"),     // Delay input (IDATAIN, DATAIN)
    .HIGH_PERFORMANCE_MODE("FALSE"), // Reduced jitter ("TRUE"), Reduced power ("FALSE")
    .IDELAY_TYPE("FIXED"),    // FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
    .IDELAY_VALUE(0),         // Input delay tap setting (0-31)
    .PIPE_SEL("FALSE"),       // Select pipelined mode, FALSE, TRUE
    .REFCLK_FREQUENCY(200.0), // IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
    .SIGNAL_PATTERN("DATA")   // DATA, CLOCK input signal
    )
  clockSyncFabricIDELAY (
    .CNTVALUEOUT(),          // 5-bit output: Counter value output
    .DATAOUT(I_d),           // 1-bit output: Delayed data output
    .C(1'b0),                // 1-bit input: Clock input
    .CE(1'b0),               // 1-bit input: Active high enable increment/decrement input
    .CINVCTRL(1'b0),         // 1-bit input: Dynamic clock inversion input
    .CNTVALUEIN(5'd0),       // 5-bit input: Counter value input
    .DATAIN(I),              // 1-bit input: Internal delay data input
    .IDATAIN(1'b0),          // 1-bit input: Data input from the I/O
    .INC(1'b0),              // 1-bit input: Increment / Decrement tap delay input
    .LD(1'b0),               // 1-bit input: Load IDELAY_VALUE input
    .LDPIPEEN(1'b0),         // 1-bit input: Enable PIPELINE register to load data input
    .REGRST(1'b0)            // 1-bit input: Active-high reset tap-delay input
   );

ISERDESE2 #(
    .DATA_RATE("DDR"),           // DDR, SDR
    .DATA_WIDTH(8),              // Parallel data width (2-8,10,14)
    .DYN_CLKDIV_INV_EN("FALSE"), // Enable DYNCLKDIVINVSEL inversion (FALSE, TRUE)
    .DYN_CLK_INV_EN("FALSE"),    // Enable DYNCLKINVSEL inversion (FALSE, TRUE)
    // INIT_Q1 - INIT_Q4: Initial value on the Q outputs (0/1)
    .INTERFACE_TYPE("NETWORKING"),// MEMORY, MEMORY_DDR3, MEMORY_QDR, NETWORKING, OVERSAMPLE
    .IOBDELAY("BOTH"),           // NONE, BOTH, IBUF, IFD
    .NUM_CE(2),                  // Number of clock enables (1,2)
    .OFB_USED("FALSE"),          // Select OFB path (FALSE, TRUE)
    .SERDES_MODE("MASTER"))      // MASTER, SLAVE
  ISERDESE2_inst (
    .O(),                        // 1-bit output: Combinatorial output
    // Q1 - Q8: 1-bit (each) output: Registered data outputs
    .Q1(O[0]),
    .Q2(O[1]),
    .Q3(O[2]),
    .Q4(O[3]),
    .Q5(O[4]),
    .Q6(O[5]),
    .Q7(O[6]),
    .Q8(O[7]),
    // SHIFTOUT1, SHIFTOUT2: 1-bit (each) output: Data width expansion output ports
    .SHIFTOUT1(),
    .SHIFTOUT2(),
    .BITSLIP(1'b0),        // 1-bit input: The BITSLIP pin performs a Bitslip operation synchronous to
    // CLKDIV when asserted (active High). Subsequently, the data seen on the Q1
    // to Q8 output ports will shift, as in a barrel-shifter operation, one
    // position every time Bitslip is invoked (DDR operation is different from
    // SDR).

    // CE1, CE2: 1-bit (each) input: Data register clock enable inputs
    .CE1(1'b1),
    .CE2(1'b1),
    .CLKDIVP(1'b0),        // 1-bit input: TBD
    // Clocks: 1-bit (each) input: ISERDESE2 clock input ports
    .CLK(sampleClkX4),     // 1-bit input: High-speed clock
    .CLKB(!sampleClkX4),   // 1-bit input: High-speed secondary clock
    .CLKDIV(sampleClk),       // 1-bit input: Divided clock
    .OCLK(1'b0),           // 1-bit input: High speed output clock used when INTERFACE_TYPE="MEMORY"
    // Dynamic Clock Inversions: 1-bit (each) input: Dynamic clock inversion pins to switch clock polarity
    .DYNCLKDIVSEL(1'b0),   // 1-bit input: Dynamic CLKDIV inversion
    .DYNCLKSEL(1'b0),      // 1-bit input: Dynamic CLK/CLKB inversion
    // Input Data: 1-bit (each) input: ISERDESE2 data input ports
    .D(1'b0),               // 1-bit input: Data input
    .DDLY(I_d),             // 1-bit input: Serial data from IDELAYE2
    .OFB(1'b0),            // 1-bit input: Data feedback from OSERDESE2
    .OCLKB(1'b0),          // 1-bit input: High speed negative edge output clock
    .RST(1'b0),            // 1-bit input: Active high asynchronous reset
    // SHIFTIN1, SHIFTIN2: 1-bit (each) input: Data width expansion input ports
    .SHIFTIN1(1'b0),
    .SHIFTIN2(1'b0));
`endif
endmodule
`default_nettype wire
