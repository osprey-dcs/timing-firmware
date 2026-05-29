/*
 * MIT License
 *
 * Copyright (c) 2024 Osprey DCS
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
 * Local Machine Protection System operations
 */
`default_nettype none
module mpsLocal #(
    parameter MPS_OUTPUT_COUNT = -1,
    parameter MPS_INPUT_COUNT  = -1,
    parameter TIMESTAMP_WIDTH  = -1,
    parameter DEBUG            = "false"
    ) (
    input  wire        sysClk,
    input  wire        sysCsrStrobe,
    input  wire        sysDataStrobe,
    input  wire [31:0] sysGPIO_OUT,
    output wire [31:0] sysStatus,
    output reg  [31:0] sysData,

                         input  wire                       acqClk,
    (*MARK_DEBUG=DEBUG*) input  wire                       acqClearTrip,
    (*MARK_DEBUG=DEBUG*) input  wire [TIMESTAMP_WIDTH-1:0] acqTimestamp,
    (*MARK_DEBUG=DEBUG*) input  wire [MPS_INPUT_COUNT-1:0] mpsInputStates_a,

                         input  wire                        mgtTxClk,
    (*MARK_DEBUG=DEBUG*) output reg  [MPS_OUTPUT_COUNT-1:0] mpsTripped = 0);

if ((MPS_OUTPUT_COUNT<1) || (MPS_OUTPUT_COUNT>8)) begin
  mpsLocal_BAD_MPS_OUTPUT_COUNT();
end
if ((MPS_INPUT_COUNT<1) || (MPS_INPUT_COUNT>8)) begin
  mpsLocal_BAD_MPS_INPUT_COUNT();
end

localparam MPS_SEL_WIDTH = (MPS_OUTPUT_COUNT<2) ? 1 : $clog2(MPS_OUTPUT_COUNT);
localparam REG_SEL_WIDTH = 4;

reg [MPS_SEL_WIDTH-1:0] sysMPSsel = 0;
reg [REG_SEL_WIDTH-1:0] sysREGsel = 0;

(*MARK_DEBUG=DEBUG*) wire [(MPS_OUTPUT_COUNT*32)-1:0] acqPerChannelData;
(*MARK_DEBUG=DEBUG*) wire      [MPS_OUTPUT_COUNT-1:0] acqPerChannelTripped;

///////////////////////////////////////////////////////////////////////////////
// System clock domain
(*MARK_DEBUG=DEBUG*) reg [MPS_INPUT_COUNT-1:0] invert = 0;
(*MARK_DEBUG=DEBUG*) reg [MPS_OUTPUT_COUNT-1:0] sysForceTrip = 0;
always @(posedge sysClk) begin
    if (sysCsrStrobe) begin
        if (sysGPIO_OUT[24]) begin
            invert <= sysGPIO_OUT[0+:MPS_INPUT_COUNT];
        end
        else if (sysGPIO_OUT[25]) begin
            sysForceTrip <= sysGPIO_OUT[0+:MPS_OUTPUT_COUNT];
        end
        else begin
            sysMPSsel <= sysGPIO_OUT[0+:MPS_SEL_WIDTH];
            sysREGsel <= sysGPIO_OUT[4+:REG_SEL_WIDTH];
        end
    end
    sysData <= acqPerChannelData[sysMPSsel*32+:32];
end
assign sysStatus = { {16-MPS_OUTPUT_COUNT{1'b0}}, sysForceTrip,
                     {8-MPS_INPUT_COUNT{1'b0}}, invert,
                     {4-REG_SEL_WIDTH{1'b0}}, sysREGsel,
                     {4-MPS_SEL_WIDTH{1'b0}}, sysMPSsel };

///////////////////////////////////////////////////////////////////////////////
// Acquisition clock domain
(*ASYNC_REG="true"*) reg [MPS_INPUT_COUNT-1:0] mpsInputs_m = 0;
reg [MPS_INPUT_COUNT-1:0] mpsInputs = 0;
always @(posedge acqClk) begin
    mpsInputs_m <= mpsInputStates_a ^ invert;
    mpsInputs   <= mpsInputs_m;
end

// Instantiate each of the MPS output handlers
genvar i;
generate
for (i = 0 ; i < MPS_OUTPUT_COUNT ; i = i + 1) begin : mpsChan
    mpsLocalChannel #(
        .MPS_INPUT_COUNT(MPS_INPUT_COUNT),
        .REG_SEL_WIDTH(REG_SEL_WIDTH),
        .TIMESTAMP_WIDTH(TIMESTAMP_WIDTH),
        .DEBUG(DEBUG))
      mpsLocalChannel_i (
        .sysClk(sysClk),
        .sysREGsel(sysREGsel),
        .sysDataStrobe(sysDataStrobe && (sysMPSsel == i)),
        .sysGPIO_OUT(sysGPIO_OUT),
        .sysData(acqPerChannelData[i*32+:32]),
        .acqClk(acqClk),
        .acqTimestamp(acqTimestamp),
        .mpsInputs(mpsInputs),
        .sysForceTrip(sysForceTrip[i]),
        .acqTripped(acqPerChannelTripped[i]),
        .acqClearTrip(acqClearTrip));
end
endgenerate

///////////////////////////////////////////////////////////////////////////////
// MGT transmit clock domain
(*ASYNC_REG="true"*) reg [MPS_OUTPUT_COUNT-1:0] mpsTripped_m = 0;
always @(posedge mgtTxClk) begin
    mpsTripped_m <= acqPerChannelTripped;
    mpsTripped   <= mpsTripped_m;
end
endmodule

module mpsLocalChannel #(
    parameter MPS_INPUT_COUNT    = -1,
    parameter REG_SEL_WIDTH      = -1,
    parameter TIMESTAMP_WIDTH    = -1,
    parameter DEBUG              = "false"
    ) (
    input  wire                     sysClk,
    input  wire [REG_SEL_WIDTH-1:0] sysREGsel,
    input  wire                     sysDataStrobe,
    input  wire              [31:0] sysGPIO_OUT,
    output reg               [31:0] sysData,

                         input  wire                        acqClk,
    (*MARK_DEBUG=DEBUG*) input  wire  [TIMESTAMP_WIDTH-1:0] acqTimestamp,
    (*MARK_DEBUG=DEBUG*) input  wire  [MPS_INPUT_COUNT-1:0] mpsInputs,
    (*MARK_DEBUG=DEBUG*) input  wire                        sysForceTrip,
    (*MARK_DEBUG=DEBUG*) output reg                         acqTripped = 1,
    (*MARK_DEBUG=DEBUG*) input  wire                        acqClearTrip);

reg [MPS_INPUT_COUNT-1:0] important = 0, firstFault = 0;
reg [MPS_INPUT_COUNT-1:0] goodState = 0;
reg [TIMESTAMP_WIDTH-1:0] whenFaulted = 0;
reg [MPS_INPUT_COUNT-1:0] faultedInputs = 0;
reg                       forceTrip;

/*
 * Registers to and from processor
 * Don't worry about clock-domain crossing since readback
 * values are stable when imporant and write transients
 * will be cleared up on the next acqClk.
 */
(*MARK_DEBUG=DEBUG*) wire trip;
always @(posedge sysClk) begin
    if (sysDataStrobe) begin
        case (sysREGsel)
        4'h0: important  <= sysGPIO_OUT[MPS_INPUT_COUNT-1:0];
        4'h1: goodState  <= sysGPIO_OUT[MPS_INPUT_COUNT-1:0];
        default: ;
        endcase
    end
    sysData <= (sysREGsel == 4'h0) ? {{32-MPS_INPUT_COUNT{1'b0}}, important} :
               (sysREGsel == 4'h1) ? {{32-MPS_INPUT_COUNT{1'b0}}, goodState} :
               (sysREGsel == 4'h2) ? {{32-MPS_INPUT_COUNT{1'b0}}, firstFault} :
               (sysREGsel == 4'h3) ? whenFaulted[32+:32] :
               (sysREGsel == 4'h4) ? whenFaulted[ 0+:32] :
               (sysREGsel == 4'h5) ? {{16-1-MPS_INPUT_COUNT{1'b0}},
                                      sysForceTrip, mpsInputs,
                                      {14{1'b0}}, trip, acqTripped} : 0;
end

/*
 * MPS
 */
(*ASYNC_REG="true"*) reg   forceTrip_m = 0;
wire [MPS_INPUT_COUNT-1:0] faults = (faultedInputs & important);

assign trip = (faults != 0) || forceTrip;

always @(posedge acqClk) begin
    faultedInputs <= mpsInputs ^ goodState;
    forceTrip_m <= sysForceTrip;
    forceTrip   <= forceTrip_m;

    if (acqClearTrip && !trip) begin
        acqTripped <= 0;
    end
    else if (trip && (acqClearTrip || !acqTripped)) begin
        firstFault  <= faults;
        whenFaulted <= acqTimestamp;
        acqTripped  <= 1;
    end
end
endmodule
`default_nettype wire
