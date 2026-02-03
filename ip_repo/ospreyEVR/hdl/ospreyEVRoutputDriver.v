// MIT License
//
// Copyright (c) 2025 Osprey DCS
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

// Single output trigger
// Nets with names starting with 'sys' are in the system clock domain

`default_nettype none
module ospreyEVRoutputDriver #(
    parameter DATA_WIDTH              = 32,
    parameter SERDES_FACTOR           = 8,
    parameter ENABLE_TRISTATE_CONTROL = 0,
    parameter ACTIVE_LOW_OUTPUTS      = 0,
    parameter DEBUG                   = "false"
    ) (
    input  wire                  sysControlUpdateToggle,
    input  wire                  sysDelayCountUpdateToggle,
    input  wire                  sysWidthCountUpdateToggle,
    input  wire [DATA_WIDTH-1:0] sysControlUpdateData,
    input  wire [DATA_WIDTH-1:0] sysDelayCountUpdateData,
    input  wire [DATA_WIDTH-1:0] sysWidthCountUpdateData,

    input  wire evrClk,
    input  wire evrBitClk,
    input  wire evrResetSERDES,
    input  wire evrLinkUp,
    input  wire evrActionIn,
    input  wire evrDbusIn,
    input  wire evrSetIn,
    input  wire evrResetIn,
    input  wire extIn_a,
    input  wire evrTriStateIn,
    output wire evrTriStateOut,
    output wire evrDriverOut);

///////////////////////////////////////////////////////////////////////////////
// Clock crossing
(*MARK_DEBUG=DEBUG*) wire [DATA_WIDTH-1:0] evrControl;
wire [DATA_WIDTH-1:0] evrDelayCount;
wire [DATA_WIDTH-1:0] evrWidthCount;
ospreyEVRoutputDriverClockCrossing #(.DATA_WIDTH(DATA_WIDTH))
  evrControl_i (
    .evrClk(evrClk),
    .sysUpdateToggle_a(sysControlUpdateToggle),
    .sysData(sysControlUpdateData),
    .evrData(evrControl));
ospreyEVRoutputDriverClockCrossing #(.DATA_WIDTH(DATA_WIDTH))
  evrDelay_i (
    .evrClk(evrClk),
    .sysUpdateToggle_a(sysDelayCountUpdateToggle),
    .sysData(sysDelayCountUpdateData),
    .evrData(evrDelayCount));
ospreyEVRoutputDriverClockCrossing #(.DATA_WIDTH(DATA_WIDTH))
  evrWidth_i (
    .evrClk(evrClk),
    .sysUpdateToggle_a(sysWidthCountUpdateToggle),
    .sysData(sysWidthCountUpdateData),
    .evrData(evrWidthCount));

///////////////////////////////////////////////////////////////////////////////
localparam SRCSEL_WIDTH = 3;
localparam SRCSEL_ZERO     = 3'd0,
           SRCSEL_PULSE    = 3'd1,
           SRCSEL_LATCH    = 3'd2,
           SRCSEL_DBUS     = 3'd3,
           SRCSEL_EXTERNAL = 3'd4,
           SRCSEL_ONE      = 3'd7;

/*
 * Settings
 */
wire [SERDES_FACTOR-1:0] firstWord = evrControl[0+:SERDES_FACTOR];
wire [SERDES_FACTOR-1:0] lastWord  = evrControl[8+:SERDES_FACTOR];
wire [SRCSEL_WIDTH-1:0] srcSel     = evrControl[16+:SRCSEL_WIDTH];
(*MARK_DEBUG=DEBUG*) reg [DATA_WIDTH:0] delayCounter = 0;
(*MARK_DEBUG=DEBUG*) wire delayCounterDone = delayCounter[DATA_WIDTH];
(*MARK_DEBUG=DEBUG*) reg [DATA_WIDTH:0] widthCounter = 0;
(*MARK_DEBUG=DEBUG*) wire widthCounterDone = widthCounter[DATA_WIDTH];

/*
 * Additional sources
 */
(*MARK_DEBUG=DEBUG*) reg evrLatch = 0;
(*ASYNC_REG="true"*) reg evrExtIn_m = 0;
reg evrExtIn = 0, evrSrc = 0;

/*
 * Value to output serializer
 */
(*MARK_DEBUG=DEBUG*) reg [SERDES_FACTOR-1:0] serdesWord = 0;

/*
 * Output driver state machine
 */
localparam [1:0] S_IDLE  = 2'd0,
                 S_ARMED = 2'd1,
                 S_DELAY = 2'd2,
                 S_WIDTH = 2'd3;
(*MARK_DEBUG=DEBUG*) reg [1:0] state = S_IDLE;

always @(posedge evrClk) begin
    evrExtIn_m <= extIn_a;
    evrExtIn   <= evrExtIn_m;

    if (evrResetIn) begin
        evrLatch <= 0;
    end
    else if (evrSetIn) begin
        evrLatch <= 1;
    end

    case (state)
    S_IDLE: begin
        delayCounter <= {1'b0, evrDelayCount} - 1;
        widthCounter <= {1'b0, evrWidthCount} - 1;
        if (srcSel == SRCSEL_PULSE) begin
            serdesWord <= 0;
            state <= S_ARMED;
        end
        else begin
            case (srcSel)
            SRCSEL_DBUS:     evrSrc <= evrDbusIn;
            SRCSEL_LATCH:    evrSrc <= evrLatch;
            SRCSEL_EXTERNAL: evrSrc <= evrExtIn;
            SRCSEL_ONE:      evrSrc <= 1;
            default:         evrSrc <= 0;
            endcase
            serdesWord <= {SERDES_FACTOR{evrSrc}};
        end
    end
    S_ARMED: begin
        if (srcSel == SRCSEL_PULSE) begin
            if (evrActionIn && evrLinkUp) begin
                delayCounter <= delayCounter - 1;
                if (delayCounterDone) begin
                    serdesWord <= firstWord;
                    state <= S_WIDTH;
                end
                else begin
                    serdesWord <= 0;
                    state <= S_DELAY;
                end
            end
            else begin
                serdesWord <= 0;
                delayCounter <= {1'b0, evrDelayCount} - 1;
                widthCounter <= {1'b0, evrWidthCount} - 1;
            end
        end
        else begin
            serdesWord <= 0;
            state <= S_IDLE;
        end
    end
    S_DELAY: begin
        delayCounter <= delayCounter - 1;
        if (delayCounterDone) begin
            serdesWord <= firstWord;
            state <= S_WIDTH;
        end
    end
    S_WIDTH: begin
        widthCounter <= widthCounter - 1;
        if (widthCounterDone) begin
            serdesWord <= lastWord;
            state <= S_IDLE;
        end
        else begin
            serdesWord <= ~0;
        end
    end
    default: state <= S_IDLE;
    endcase
end

generate
if (SERDES_FACTOR == 1) begin
  assign evrDriverOut = serdesWord;
  if (ENABLE_TRISTATE_CONTROL) begin
    assign evrTriStateOut = evrTriStateIn;
  end
  else begin
    assign evrTriStateOut = 1'b0;
  end
end
else begin
  /////////////////////////////////////////////////////////////////////////////
  // Output serializer to get finer delay/width control
  // Based on wizard-generated example
  wire [7:0] serdesPad = ACTIVE_LOW_OUTPUTS ?
                                         ~{{8-SERDES_FACTOR{1'b0}}, serdesWord}
                                        : {{8-SERDES_FACTOR{1'b0}}, serdesWord};
  wire evrSERDESout, evrSERDEStriOut;
  OSERDESE2 #(
    .DATA_RATE_OQ   ("DDR"),
    .DATA_RATE_TQ   ("SDR"),
    .DATA_WIDTH     (SERDES_FACTOR),
    .TRISTATE_WIDTH (1),
    .SERDES_MODE    ("MASTER"))
  evrDriverSERDES (
    .D1             (serdesPad[0]),
    .D2             (serdesPad[1]),
    .D3             (serdesPad[2]),
    .D4             (serdesPad[3]),
    .D5             (serdesPad[4]),
    .D6             (serdesPad[5]),
    .D7             (serdesPad[6]),
    .D8             (serdesPad[7]),
    .T1             (ENABLE_TRISTATE_CONTROL ? evrTriStateIn : 1'b0),
    .T2             (1'b0),
    .T3             (1'b0),
    .T4             (1'b0),
    .SHIFTIN1       (1'b0),
    .SHIFTIN2       (1'b0),
    .SHIFTOUT1      (),
    .SHIFTOUT2      (),
    .OCE            (1'b1),
    .CLK            (evrBitClk),
    .CLKDIV         (evrClk),
    .OQ             (evrSERDESout),
    .TQ             (evrSERDEStriOut),
    .OFB            (),
    .TFB            (),
    .TBYTEIN        (1'b0),
    .TBYTEOUT       (),
    .TCE            (ENABLE_TRISTATE_CONTROL),
    .RST            (evrResetSERDES));
  if (ENABLE_TRISTATE_CONTROL) begin
    assign evrDriverOut = evrSERDESout;
    assign evrTriStateOut = evrSERDEStriOut;
  end
  else begin
    OBUF evrHwObuf(.I(evrSERDESout), .O(evrDriverOut));
    assign evrTriStateOut = 1'b0;
  end
end
endgenerate

endmodule

///////////////////////////////////////////////////////////////////////////////
// Clock-crossing
module ospreyEVRoutputDriverClockCrossing #(parameter DATA_WIDTH = -1) (
    input  wire                   evrClk,
    input  wire                   sysUpdateToggle_a,
    input  wire [ DATA_WIDTH-1:0] sysData,
    output reg  [ DATA_WIDTH-1:0] evrData);
(*ASYNC_REG="true"*) reg evrUpdateToggle_m = 0;
reg evrUpdateToggle = 0, evrUpdateToggle_d = 0;
always @(posedge evrClk) begin
    evrUpdateToggle_m <= sysUpdateToggle_a;
    evrUpdateToggle   <= evrUpdateToggle_m;
    evrUpdateToggle_d <= evrUpdateToggle;
    if (evrUpdateToggle != evrUpdateToggle_d) begin
        evrData <= sysData;
    end
end
endmodule
`default_nettype wire
