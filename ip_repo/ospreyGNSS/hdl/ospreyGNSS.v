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
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

/*
 * Bsed on Axi-Lite example without additional cycle of read latency
 *        WREADY is the write strobe.
 *        (RVALID && RREADY) is the read strobe.
 *
 * Based on the excellent tutorials by Dan Gisselquist.
 *                              https://zipcpu.com/blog/2020/03/08/easyaxil.html
 */

`default_nettype none

module ospreyGNSS #(
    ////////////////////// Application-specific Parameters ///////////////////
    parameter C_S_AXI_ADDR_WIDTH   = 5,
    parameter C_S_AXI_ACLK_FREQ_HZ = 100000000,
    parameter BAUD                 = 9600,
    parameter DEBUG                = "false",
    ////////////////////// AXI-Lite Boilerplate Parameters ///////////////////
    parameter C_S_AXI_DATA_WIDTH = 32
    ) (
    ////////////////////// Application-specific Ports ///////////////////
    input  wire                          PPS,
    input  wire                          rxD,
    output wire                          txD,
    output reg                           ppsValid = 0,
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
    output reg                           s_axi_wready = 0,
    input  wire                    [3:0] s_axi_wstrb,
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

///////////////////////////////////////////////////////////////////////////////
// Validate PPS
localparam PPS_TOO_FAST_RELOAD = ((C_S_AXI_ACLK_FREQ_HZ / 100) * 99) - 1;
localparam PPS_TOO_SLOW_RELOAD = ((C_S_AXI_ACLK_FREQ_HZ / 100) * 101) - 1;
localparam PPS_TOO_FAST_WIDTH = $clog2(PPS_TOO_FAST_RELOAD+1) + 1;
localparam PPS_TOO_SLOW_WIDTH = $clog2(PPS_TOO_FAST_RELOAD+1) + 1;

(*ASYNC_REG="true"*) reg ppsMarker_m = 0;
(*MARK_DEBUG=DEBUG*) reg ppsMarker = 0, ppsMarker_d = 0;

(*MARK_DEBUG=DEBUG*) reg [PPS_TOO_FAST_WIDTH-1:0] ppsTooFastCounter =
                                                            PPS_TOO_FAST_RELOAD;
wire ppsTooFast = !ppsTooFastCounter[PPS_TOO_FAST_WIDTH-1];
(*MARK_DEBUG=DEBUG*) reg [PPS_TOO_SLOW_WIDTH-1:0] ppsTooSlowCounter =
                                                            PPS_TOO_SLOW_RELOAD;
wire ppsTooSlow = ppsTooSlowCounter[PPS_TOO_SLOW_WIDTH-1];

reg [31:0] ppsCounter;

always @(posedge s_axi_aclk) begin
    ppsMarker_m <= PPS;
    ppsMarker   <= ppsMarker_m;
    ppsMarker_d <= ppsMarker;
    if (ppsMarker && !ppsMarker_d) begin
        ppsTooFastCounter <= PPS_TOO_FAST_RELOAD;
        ppsTooSlowCounter <= PPS_TOO_SLOW_RELOAD;
        if (ppsTooFast || ppsTooSlow) begin
            ppsValid <= 0;
        end
        else begin
            ppsValid <= 1;
            ppsCounter <= ppsCounter + 1;
        end
    end
    else begin
        if (ppsTooFast) begin
            ppsTooFastCounter <= ppsTooFastCounter - 1;
        end
        if (ppsTooSlow) begin
            ppsValid <= 0;
        end
        else begin
            ppsTooSlowCounter <= ppsTooSlowCounter - 1;
        end
    end
end

///////////////////////////////////////////////////////////////////////////////
// UART receiver
localparam UART_HALF_BIT_DIVISOR = (C_S_AXI_ACLK_FREQ_HZ + BAUD) / (2 * BAUD);
localparam UART_FULL_BIT_DIVISOR = (C_S_AXI_ACLK_FREQ_HZ + (BAUD / 2)) / BAUD;
localparam UART_HALF_BIT_RELOAD = UART_HALF_BIT_DIVISOR - 2;
localparam UART_FULL_BIT_RELOAD = UART_FULL_BIT_DIVISOR - 2;
localparam UART_BAUD_COUNTER_WIDTH = $clog2(UART_FULL_BIT_RELOAD+1) + 1;
reg [UART_BAUD_COUNTER_WIDTH-1:0] uartRxBaudCounter = 0;
(*MARK_DEBUG=DEBUG*) wire uartRxBaudCounterDone =
                                   uartRxBaudCounter[UART_BAUD_COUNTER_WIDTH-1];

localparam UART_RX_BIT_COUNTER_RELOAD = 8 - 2;
localparam UART_RX_BIT_COUNTER_WIDTH = $clog2(UART_RX_BIT_COUNTER_RELOAD+1) + 1;
reg [UART_RX_BIT_COUNTER_WIDTH-1:0] uartRxBitCounter = 0;
(*MARK_DEBUG=DEBUG*) wire uartRxBitCounterDone =
                                  uartRxBitCounter[UART_RX_BIT_COUNTER_WIDTH-1];

localparam UART_RX_S_AWAIT_START = 2'd0,
           UART_RX_S_CHECK_START = 2'd1,
           UART_RX_S_RECEIVING   = 2'd2,
           UART_RX_S_STOP        = 2'd3;
(*MARK_DEBUG=DEBUG*) reg [1:0] uartRxState = UART_RX_S_AWAIT_START;

(*ASYNC_REG="true"*) reg uartRxd_m = 0;
(*MARK_DEBUG=DEBUG*) reg uartRxD = 0, uartRxD_d;

(*MARK_DEBUG=DEBUG*) reg [7:0] uartRxShiftReg;
(*MARK_DEBUG=DEBUG*) reg uartRxDataStrobe = 0;
wire [6:0] uartRxChar = uartRxShiftReg[6:0]; /* Ignore parity bit */

reg [C_S_AXI_DATA_WIDTH-1:0] uartRxStartGlitchCount = 0;
reg [C_S_AXI_DATA_WIDTH-1:0] uartRxFramingErrorCount = 0;

always @(posedge s_axi_aclk) begin
    /*
     * Synchronize received data
     */
    uartRxd_m <= rxD;
    uartRxD   <= uartRxd_m;
    uartRxD_d <= uartRxD;

    /*
     * Maintain serial rate counter
     */
    if (uartRxState == UART_RX_S_AWAIT_START) begin
        uartRxBaudCounter <= UART_HALF_BIT_RELOAD;
    end
    else if (uartRxBaudCounterDone) begin
        uartRxBaudCounter <= UART_FULL_BIT_RELOAD;
    end
    else begin
        uartRxBaudCounter <= uartRxBaudCounter - 1;
    end

    /*
     * UART state machine
     */
    case (uartRxState)
    UART_RX_S_AWAIT_START: begin
        uartRxDataStrobe <= 0;
        uartRxBitCounter <= UART_RX_BIT_COUNTER_RELOAD;
        if ((uartRxD == 0) && (uartRxD_d == 1)) begin
            uartRxState <= UART_RX_S_CHECK_START;
        end
    end
    UART_RX_S_CHECK_START: begin
        if (uartRxBaudCounterDone) begin
            if (uartRxD == 0) begin
                uartRxState <= UART_RX_S_RECEIVING;
            end
            else begin
                uartRxStartGlitchCount <= uartRxStartGlitchCount + 1;
                uartRxState <= UART_RX_S_CHECK_START;
            end
        end
    end
    UART_RX_S_RECEIVING: begin
        if (uartRxBaudCounterDone) begin
            uartRxShiftReg <= {uartRxD, uartRxShiftReg[7:1]};
            uartRxBitCounter <= uartRxBitCounter - 1;
            if (uartRxBitCounterDone) begin
                uartRxState <= UART_RX_S_STOP;
            end
        end
    end
    UART_RX_S_STOP: begin
        if (uartRxBaudCounterDone) begin
            if (uartRxD == 0) begin
                uartRxFramingErrorCount <= uartRxFramingErrorCount + 1;
            end
            else begin
                uartRxDataStrobe <= 1;
            end
            uartRxState <= UART_RX_S_AWAIT_START;
        end
    end
    default: uartRxState <= UART_RX_S_AWAIT_START;
    endcase
end

///////////////////////////////////////////////////////////////////////////////
// UART transmitter
reg [UART_BAUD_COUNTER_WIDTH-1:0] uartTxBaudCounter = 0;
(*MARK_DEBUG=DEBUG*) wire uartTxBaudCounterDone =
                                   uartTxBaudCounter[UART_BAUD_COUNTER_WIDTH-1];

localparam UART_TX_BIT_COUNTER_RELOAD = 10 - 2;
localparam UART_TX_BIT_COUNTER_WIDTH = $clog2(UART_TX_BIT_COUNTER_RELOAD+1) + 1;
reg [UART_TX_BIT_COUNTER_WIDTH-1:0] uartTxBitCounter = 0;
(*MARK_DEBUG=DEBUG*) wire uartTxBitCounterDone =
                                  uartTxBitCounter[UART_TX_BIT_COUNTER_WIDTH-1];

(*MARK_DEBUG=DEBUG*) wire uartTxStart;
(*MARK_DEBUG=DEBUG*) reg uartTxBusy = 0;
(*MARK_DEBUG=DEBUG*) reg [8:0] uartTxShiftReg = ~0;
assign txD = uartTxShiftReg[0];

always @(posedge s_axi_aclk) begin
    if (uartTxBusy) begin
        uartTxBaudCounter <= uartTxBaudCounter - 1;
        if (uartTxBaudCounterDone) begin
            uartTxBitCounter <= uartTxBitCounter - 1;
            uartTxBaudCounter <= UART_FULL_BIT_RELOAD;
            uartTxShiftReg <= {1'b1, uartTxShiftReg[8:1]};
            if (uartTxBitCounterDone) begin
                uartTxBusy <= 0;
            end
        end
    end
    else begin
        uartTxBaudCounter <= UART_FULL_BIT_RELOAD;
        uartTxBitCounter <= UART_TX_BIT_COUNTER_RELOAD;
        if (uartTxStart) begin
            uartTxShiftReg <= {s_axi_wdata[7:0], 1'b0};
            uartTxBusy <= 1;
        end
    end
end

///////////////////////////////////////////////////////////////////////////////
// NMEA message state machine
// Forward only valid sentences to processor

(*MARK_DEBUG=DEBUG*) reg enableReception = 0;

localparam RING_BUFFER_ADDR_WIDTH = 10;
reg [7:0] dpram [0:(1<<RING_BUFFER_ADDR_WIDTH)-1];
reg [7:0] dpramQ;
(*MARK_DEBUG=DEBUG*) reg [RING_BUFFER_ADDR_WIDTH-1:0] readPtr = 0;
(*MARK_DEBUG=DEBUG*) reg [RING_BUFFER_ADDR_WIDTH-1:0] msgPtr = 0;
(*MARK_DEBUG=DEBUG*) reg [RING_BUFFER_ADDR_WIDTH-1:0] fillPtr = 0;
wire [RING_BUFFER_ADDR_WIDTH-1:0] nextPtr = fillPtr + 1;

localparam S_IDLE     = 3'd0,
           S_MESSAGE  = 3'd1,
           S_CHECK_HI = 3'd2,
           S_CHECK_LO = 3'd3,
           S_VERIFY   = 3'd4;
(*MARK_DEBUG=DEBUG*) reg [2:0] state = S_IDLE;

(*MARK_DEBUG=DEBUG*) reg [7:0] checksum;
reg [31:0] overrunCount       = 0;
reg [31:0] badMessageCount    = 0;
reg [31:0] checksumErrorCount = 0;

(*MARK_DEBUG=DEBUG*) reg [PPS_TOO_SLOW_WIDTH-1:0] messageWatchdog =
                                                            PPS_TOO_SLOW_RELOAD;
wire messageWatchdogTimeout = messageWatchdog[PPS_TOO_SLOW_WIDTH-1];

/*
 * Convert ASCII hex digit (upper or lower case) to binary nybble
 */
function [3:0] hexVal;
	input [6:0] c;
	begin
		hexVal = ((c >= "0") && (c <= "9")) ? c[3:0] : (c[3:0] + 4'd9);
	end
endfunction

always @(posedge s_axi_aclk) begin
    dpramQ <= dpram[readPtr];
    if (enableReception == 0) begin
        messageWatchdog <= PPS_TOO_SLOW_RELOAD;
        msgPtr <= 0;
        fillPtr <= 0;
        state <= S_IDLE;
    end
    else if (state == S_VERIFY) begin
        if (checksum == 0) begin
            /*
             * Accept the message
             */
            msgPtr <= fillPtr;
            messageWatchdog <= PPS_TOO_SLOW_RELOAD;
        end
        else begin
            checksumErrorCount <= checksumErrorCount + 1;
            fillPtr <= msgPtr; /* Flush the message */
        end
        state <= S_IDLE;
    end
    else begin
        if (!messageWatchdogTimeout) begin
            messageWatchdog <= messageWatchdog - 1;
        end
        if (uartRxDataStrobe) begin
            dpram[fillPtr] <= {1'b0, uartRxChar};
            if (nextPtr == readPtr) begin
                overrunCount <= overrunCount + 1;
            end
            else begin
                if (uartRxChar == "$") begin
                    if (state != S_IDLE) begin
                        badMessageCount <= badMessageCount + 1;
                    end
                    /*
                     * Accept character and throw away any
                     * partial message already received or
                     * the trailer from the previous message.
                     */
                    fillPtr <= msgPtr + 1;
                    checksum <= 0;
                    state <= S_MESSAGE;
                end
                else case (state)
                S_IDLE: begin
                    /*
                     * Reception has started while a message is
                     * already being received.
                     * Ignore characters until a '$' arrives.
                     */
                end
                S_MESSAGE: begin
                    fillPtr <= fillPtr + 1;
                    if (uartRxChar == "*") begin
                        state <= S_CHECK_HI;
                    end
                    else begin
                        checksum <= checksum ^ {1'b0, uartRxChar};
                    end
                end
                S_CHECK_HI: begin
                    checksum[4+:4] <= checksum[4+:4] ^ hexVal(uartRxChar);
                    state <= S_CHECK_LO;
                end
                S_CHECK_LO: begin
                    checksum[0+:4] <= checksum[0+:4] ^ hexVal(uartRxChar);
                    state <= S_VERIFY;
                end
                default: state <= S_IDLE;
                endcase
            end
        end
    end
end

///////////////////////////////////////////////////////////////////////////////
// AXI glue

// Register addresses
localparam REG_IDX_CSR                     = 3'd0,
           REG_IDX_PPS_COUNTER             = 3'd1,
           REG_IDX_RX_FIFO                 = 3'd2,
           REG_IDX_RX_START_GLITCH_COUNT   = 3'd3,
           REG_IDX_RX_FRAMING_ERROR_COUNT  = 3'd4,
           REG_IDX_RX_OVERRUN_COUNT        = 3'd5,
           REG_IDX_RX_BAD_MESSAGE_COUNT    = 3'd6,
           REG_IDX_RX_CHECKSUM_ERROR_COUNT = 3'd7;

// Multiplex register read values
reg [C_S_AXI_DATA_WIDTH-1:0] readData;
assign s_axi_rdata = readData;

(*MARK_DEBUG=DEBUG*) wire[31:0] statusReg = {
                                {7{1'b0}}, messageWatchdogTimeout,
                                {7{1'b0}}, ppsValid,
                                {7{1'b0}}, uartTxBusy,
                                {7{1'b0}}, enableReception };

assign uartTxStart = s_axi_wready && (s_axi_awaddr[2+:3] == REG_IDX_RX_FIFO);

always @(posedge s_axi_aclk) begin
    /*
     * Initialization
     */
    if (enableReception == 0) begin
        readPtr <= 0;
    end

    /*
     * Register writes
     */
    if (s_axi_wready) begin
       case (s_axi_awaddr[2+:3])
        REG_IDX_CSR: begin
            if      (s_axi_wdata[1]) enableReception <= 0;
            else if (s_axi_wdata[0]) enableReception <= 1;
        end
       endcase
    end

    /*
     * Register reads
     */
   case (s_axi_araddr[2+:3])
    REG_IDX_CSR: begin
        readData <= statusReg;
    end
    REG_IDX_PPS_COUNTER: begin
        readData <= ppsCounter;
    end
    REG_IDX_RX_FIFO: begin
        if (readPtr == msgPtr) begin
            readData <= {1'b1, {C_S_AXI_DATA_WIDTH-1{1'bx}}};
        end
        else begin
            /*
             * There is the implicit assumption that FIFO reads
             * are separated by more than the DPRAM read latency
             */
            readData <= {{C_S_AXI_DATA_WIDTH-8{1'b0}}, dpramQ};
            if ((s_axi_rvalid && s_axi_rready)) begin
                readPtr <= readPtr + 1;
            end
        end
    end
    REG_IDX_RX_START_GLITCH_COUNT: begin
        readData <= uartRxStartGlitchCount;
    end
    REG_IDX_RX_FRAMING_ERROR_COUNT: begin
        readData <= uartRxFramingErrorCount;
    end
    REG_IDX_RX_OVERRUN_COUNT: begin
        readData <= overrunCount;
    end
    REG_IDX_RX_BAD_MESSAGE_COUNT: begin
        readData <= badMessageCount;
    end
    REG_IDX_RX_CHECKSUM_ERROR_COUNT: begin
        readData <= checksumErrorCount;
    end
    default: readData <= 0;
    endcase
end

endmodule

`default_nettype wire
