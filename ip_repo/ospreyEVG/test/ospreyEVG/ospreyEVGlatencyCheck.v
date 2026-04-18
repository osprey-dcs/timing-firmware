`timescale  1 ns / 1 ns
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
    output reg [31:0] sysStatus,

    input wire sampleClk,
    input wire sampleClkX4,

    input  wire                      [RX_COUNT-1:0] mgtRxClks,
    input  wire     [(RX_COUNT*MGT_DATA_WIDTH)-1:0] mgtRxChars,
    input  wire [(RX_COUNT*(MGT_DATA_WIDTH/8))-1:0] mgtRxCharIsK,

    input  wire                          mgtTxClk,
    input  wire     [MGT_DATA_WIDTH-1:0] mgtTxChars,
    input  wire [(MGT_DATA_WIDTH/8)-1:0] mgtTxCharIsK,

    output reg [(RX_COUNT*LATENCY_WIDTH)-1:0] latencies
);

// FAKE!!

endmodule
