`timescale  1 ns / 100 ps
module test;

`include "../axi_testing.vh"

`define assert_eq(L, R) \
    $display("%s 0x%x === 0x%x", L===R ? "ok" : "not ok", L, R); \
    if(L!==R) $stop

always #5 ACLK <= ~ACLK; // 100MHz

reg evrBitClk = 0;
always #0.4 evrBitClk <= ~evrBitClk; // 2500 MHz

localparam FRAME_SIZE = 20;
integer evrBitCnt = 0;
always @(posedge evrBitClk)
    evrBitCnt <= (evrBitCnt + 1) % FRAME_SIZE;
wire evrClk = evrBitCnt < FRAME_SIZE/2; // 125MHz

reg evrLinkUp = 0;
reg [15:0] evrRxChars = 0;
reg  [1:0] evrRxCharIsK = 0;
reg  [8:0] nextCode;

reg [23:0] hwInputs = 0;
wire [23:0] hwOutputs;
reg [15:0] hwOutputsHist [0:7];

genvar pin, t;
for(pin=0; pin<8; pin=pin+1) begin : history
    for(t=1; t<16; t=t+1)
        always @(posedge evrClk)
            hwOutputsHist[pin][t] <= hwOutputsHist[pin][t-1];

    always @(posedge evrClk)
        hwOutputsHist[pin][0] <= hwOutputs[pin];
end
wire [15:0] hwOutputsHist3 = hwOutputsHist[3];

wire [25:0] evrActionStrobes;

ospreyEVR_v1_0 #(
    .HARDWARE_OUTPUT_COUNT(24),
    .SERDES_FACTOR(1),
    .ACTIVE_LOW_OUTPUTS(0),
    .ACTION_STROBES_WIDTH(26)
) dut(
    .evrClk(evrClk),
    .evrBitClk(evrBitClk),
    .evrLinkUp(evrLinkUp),
    .evrRxChars(evrRxChars),
    .evrRxCharIsK(evrRxCharIsK),
    .evrHardwareOutputs(hwOutputs),
    .hwDriverIn_a(hwInputs),
    .evrPPSstrobe(),
    .evrPPSmarker(),
    .evrActionStrobes(evrActionStrobes),
    .evrDistributedBus(),
    .evrTimestampValid(),
    .evrTimestamp(),
    .sysTimestamp(),
    .s_axi_aclk(ACLK),
    .s_axi_aresetn(ARESETn),
    .s_axi_arvalid(ARVALID),
    .s_axi_arready(ARREADY),
    .s_axi_arprot(3'b000),
    .s_axi_araddr(ARADDR[10:0]),
    .s_axi_rdata(RDATA),
    .s_axi_rvalid(RVALID),
    .s_axi_rready(RREADY),
    .s_axi_rresp(RRESP),
    .s_axi_awvalid(AWVALID),
    .s_axi_awready(AWREADY),
    .s_axi_awprot(3'b000),
    .s_axi_awaddr(AWADDR[10:0]),
    .s_axi_wvalid(WVALID),
    .s_axi_wready(WREADY),
    .s_axi_wstrb(4'b0000),
    .s_axi_wdata(WDATA),
    .s_axi_bvalid(BVALID),
    .s_axi_bready(BREADY),
    .s_axi_bresp(BRESP)
);

`ifdef __ICARUS__
initial begin
    #10000
    $display("Timeout!");
    $stop;
end
`endif

integer currentCase = 0;
initial begin
`ifdef __ICARUS__
    string vcd;
    if($value$plusargs("vcd=%s", vcd)) begin
        $display("# Dump to %s", vcd);
        $dumpfile(vcd);
        $dumpvars(0,test);
    end
`endif

    $display("Reset");
    @(posedge ACLK);
    ARESETn <= 0;
    @(posedge ACLK);
    ARESETn <= 1;

    start_case("After reset");
    axi.read(4 * dut.REG_INDEX_CSR, {
        18'h0, // unused
        1'b0, // ACTIVE_LOW_OUTPUTS
        4'd1, // SERDES_FACTOR
        5'd24, // HARDWARE_OUTPUT_COUNT
        4'h0 // status bits
    });

    start_case("Remap outputs");
    // phys | logical (zero indicies)
    //    2 | 4
    //    4 | 3
    //    3 | 2
    axi.write(4 * dut.REG_INDEX_RAVEL,    {16'd2, 16'd4});
    axi.write(4 * dut.REG_INDEX_RAVEL,    {16'd4, 16'd3});
    axi.write(4 * dut.REG_INDEX_RAVEL,    {16'd3, 16'd2});

    start_case("Static 1/0 2nd output");
    `assert_eq(hwOutputs, 8'h00);
    $display("# select second output");
    axi.write(4 * dut.REG_INDEX_TRIGGER_SELECT, 32'd1);
    axi.write(4 * dut.REG_INDEX_TRIGGER_CONTROL, {
        13'hx,
        dut.outputDriver[0].ospreyEVRoutputDriver_i.SRCSEL_ZERO,
        7'hx, 1'b0, // falling edge
        7'hx, 1'b1 // rising edge
    });
    `assert_eq(hwOutputs, 8'h00);
    axi.write(4 * dut.REG_INDEX_TRIGGER_CONTROL, {
        13'hx,
        dut.outputDriver[0].ospreyEVRoutputDriver_i.SRCSEL_ONE,
        7'hx, 1'b0, // falling edge
        7'hx, 1'b1 // rising edge
    });
    repeat(4) @(posedge evrClk); // latency...
    `assert_eq(hwOutputs, 8'h02);

    start_case("Pulse 3rd output");
    axi.write(4 * dut.REG_INDEX_TRIGGER_SELECT, 32'd2);
    axi.write(4 * dut.REG_INDEX_TRIGGER_CONTROL, {
        13'hx,
        dut.outputDriver[0].ospreyEVRoutputDriver_i.SRCSEL_PULSE,
        7'hx, 1'b0, // falling edge
        7'hx, 1'b0 // rising edge
    });
    axi.write(4 * dut.REG_INDEX_TRIGGER_DELAY, 32'd0); // delay zero (establish latency)
    axi.write(4 * dut.REG_INDEX_TRIGGER_WIDTH, 32'd3);
    axi.write(4 * dut.REG_INDEX_ACTION_RAM, {14'hx, 2'b10, 8'd2, 8'd15}); // event 15 triggers 3rd action
    axi.read (4 * dut.REG_INDEX_ACTION_RAM, 32'h00000004);
    @(negedge evrClk);
    evrLinkUp <= 1;
    nextCode <= 9'd15;
    hwOutputsHist[3] <= 16'hx;
    while(!evrActionStrobes[2]) // exclude latency related to event decode/lookup
        @(posedge evrClk);
    $display("# action bit 3 delay 0");
    repeat(10) @(posedge evrClk); // measure delay relative to strobe, look back 12 ticks
    $display("X 16'b%b", hwOutputsHist[3]);
    `assert_eq(hwOutputsHist[3], 16'bxxx0000011100000);

    axi.write(4 * dut.REG_INDEX_TRIGGER_DELAY, 32'd2); // delay 2
    axi.write(4 * dut.REG_INDEX_TRIGGER_WIDTH, 32'd3);
    @(negedge evrClk);
    nextCode <= 9'd15;
    hwOutputsHist[3] <= 16'hx;
    while(!evrActionStrobes[2])
        @(posedge evrClk);
    $display("# action bit 3 delay 2");
    repeat(10) @(posedge evrClk);
    $display("X 16'b%b", hwOutputsHist[3]);
    `assert_eq(hwOutputsHist[3], 16'bxxx0000000111000);

    start_case("Clear action");
    axi.write(4 * dut.REG_INDEX_ACTION_RAM, {14'hx, 2'b00, 8'd3, 8'd15}); // event 15 read 4th action
    axi.read (4 * dut.REG_INDEX_ACTION_RAM, 32'h00000004);
    axi.write(4 * dut.REG_INDEX_ACTION_RAM, {14'hx, 2'b01, 8'd2, 8'd15}); // event 15 triggers 3rd action
    axi.read (4 * dut.REG_INDEX_ACTION_RAM, 32'h00000000);

    start_case("End");
`ifdef __ICARUS__
    #10
    $finish();
`endif
end

task start_case;
    input string label;
begin
    currentCase = currentCase + 1;
    $display("### CASE %d %s", currentCase, label);
end
endtask

always @(negedge evrClk) begin
    if(nextCode!=0) begin
        $display("# Send 0x%02x", nextCode);
        {evrRxCharIsK[0], evrRxChars[15:8]} <= nextCode;
        nextCode <= 9'hxxx;
    end else begin
        {evrRxCharIsK[1], evrRxChars[15:8]} <= 0;
    end
end

endmodule
