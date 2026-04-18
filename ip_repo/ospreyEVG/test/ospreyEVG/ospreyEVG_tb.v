`timescale  1 ns / 1 ns
module test;

`include "axi_testing.vh"

`define assert_eq(L, R) begin \
    $display("%s 0x%x === 0x%x", L===R ? "ok" : "not ok", L, R); \
    if(L!==R) $stop; \
end

reg evgClk = 1;
always #4 evgClk <= ~evgClk; // 125MHz

reg ppsMarker_a = 0;
reg [7:0] hwInputs_a = 0;

always #5 ACLK <= ~ACLK; // 100MHz

ospreyEVG_v1_0 #(
    .EVGCLK_FREQUENCY(125000000),
    .INPUT_COUNT(8),
    .TIMER_COUNT(2),
    .RX_COUNT(1),
    .HW_TRIGGER_COUNT(8),
    .SEQRAM_BANK_COUNT(2),
    .SEQRAM_ADDR_WIDTH(11),
    .C_S_AXI_ADDR_WIDTH(12)
) evg (
    .evgClk(evgClk),
    .ppsMarker_a(ppsMarker_a),
    .hwInputs_a(hwInputs_a),
    .sampleClk(1'bx),
    .sampleClkX4(1'bx),
    .evgRxClks(1'bx),
    .evgRxChars(16'hxxxx),
    .evgRxCharIsK(2'bxx),

    .s_axi_aclk(ACLK),
    .s_axi_aresetn(ARESETn),
    .s_axi_arvalid(ARVALID),
    .s_axi_arready(ARREADY),
    .s_axi_arprot(3'bxxx),
    .s_axi_araddr(ARADDR),
    .s_axi_rdata(RDATA),
    .s_axi_rvalid(RVALID),
    .s_axi_rready(RREADY),
    .s_axi_rresp(RRESP),
    .s_axi_awvalid(AWVALID),
    .s_axi_awready(AWREADY),
    .s_axi_awprot(3'bxxx),
    .s_axi_awaddr(AWADDR),
    .s_axi_wvalid(WVALID),
    .s_axi_wready(WREADY),
    .s_axi_wstrb(4'hx),
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
        $display("Dump to %s", vcd);
        $dumpfile(vcd);
        $dumpvars(0,test);
    end
`endif

    $display("Reset");
    @(posedge ACLK);
    ARESETn <= 0;
    @(posedge ACLK);
    ARESETn <= 1;

    start_case("test_config");
    test_config();
    start_case("test_timer");
    test_timer();
    start_case("test_hwInput");
    test_hwInput();
    start_case("test_swEvent");
    test_swEvent();
    start_case("test_seq");
    test_seq();

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
    resetEventLog();
end
endtask

task test_config;
begin
    axi.read(evg.REG_IDX_CONFIG*4, 32'h0001B228);
    axi.read(evg.REG_IDX_CSR*4, 32'h00000000);
    /* Setup 1 to 1 mapping.  physical input to "hw" input
     */
    axi.write(evg.REG_IDX_HW_TRIGGER_MAP*4, 32'h87654321);
    `assert_eq(evg.hwTriggerMap, 32'h87654321);
end
endtask

task test_timer;
begin
    axi.write(evg.REG_IDX_TIMER_CONFIG_BASE*4 + (0<<3) + 4, 32'h0000000b); // load countdown
    axi.write(evg.REG_IDX_TIMER_CONFIG_BASE*4 + (0<<3) + 0, 32'h00000064); // event 100
    axi.write(evg.REG_IDX_TIMER_CSR*4, 32'h00000003); // start timer 0

    `assert_eq(evg.timerTriggerEnables, 2'b01);
    `assert_eq(evg.timerEventCodes, 16'h0064);
    waitForEvent(8'h64);

    axi.write(evg.REG_IDX_TIMER_CSR*4, 32'h00000001); // stop timer 0
    axi.write(evg.REG_IDX_TIMER_CONFIG_BASE*4 + (0<<3) + 4, 32'h00000008); // load countdown
    axi.write(evg.REG_IDX_TIMER_CONFIG_BASE*4 + (0<<3) + 0, 32'h00000065); // event 101
    axi.write(evg.REG_IDX_TIMER_CSR*4, 32'h00000003); // start timer 0
    `assert_eq(evg.timerTriggerEnables, 2'b01);
    `assert_eq(evg.timerEventCodes, 16'h0065);
    waitForEvent(8'h65);

    axi.write(evg.REG_IDX_TIMER_CONFIG_BASE*4 + (0<<3) + 0, 32'h00000066); // event 102
    waitForEvent(8'h66);

    axi.write(evg.REG_IDX_TIMER_CSR*4, 32'h00000001); // stop timer 0
    axi.write(evg.REG_IDX_TIMER_CONFIG_BASE*4 + (0<<3) + 0, 32'h00000000); // clear event
    axi.write(evg.REG_IDX_TIMER_CONFIG_BASE*4 + (0<<3) + 4, 32'hffffffff); // load countdown
    `assert_eq(evg.timerTriggerEnables, 2'b00);
    `assert_eq(evg.timerEventCodes, 16'h0000);
    `assert_eq(evg.timerRequester[0].timerInitVal, 32'hffffffff);
end
endtask

task test_hwInput;
begin
    axi.write(evg.REG_IDX_HW_TRIGGER_CONFIG*4, 32'h00000264); // 2nd input, rising, event 100
    axi.write(evg.REG_IDX_HW_TRIGGER_CONFIG*4, 32'h00000365); // 2nd input, falling, event 101
    `assert_eq(evg.hwTriggerEnables, 16'h000c); // ??

    hwInputs_a[1] <= 1'b1;
    waitForEvent(8'h64);
    hwInputs_a[1] <= 1'b0;
    waitForEvent(8'h65);

    axi.write(evg.REG_IDX_HW_TRIGGER_CONFIG*4, 32'h00000200); // 2nd input, rising, disable
    hwInputs_a[1] <= 1'b1;
    @(posedge evgClk);
    hwInputs_a[1] <= 1'b0;
    waitForEvent(8'h65);

    axi.write(evg.REG_IDX_HW_TRIGGER_CONFIG*4, 32'h00000300); // 2nd input, falling, disable
end
endtask

task test_swEvent;
begin
    axi.write(evg.REG_IDX_SW_EVENT*4, 8'h14);
    waitForEvent(8'h14);
    axi.write(evg.REG_IDX_SW_EVENT*4, 8'h15);
    waitForEvent(8'h15);
end
endtask

task test_seq;
begin
    // BANK.OFFSET
    axi.write(evg.REG_IDX_SEQ_ADDR_CODE*4, 32'h80000010); // offset 0.0, code 16
    axi.write(evg.REG_IDX_SEQ_ADDR_CODE*4, 32'h00000000); // offset 0.0
    axi.write(evg.REG_IDX_SEQ_GAP*4, 32'h00000040); // delay 64

    axi.write(evg.REG_IDX_SEQ_ADDR_CODE*4, 32'h80000111); // offset 0.1, code 17
    axi.write(evg.REG_IDX_SEQ_ADDR_CODE*4, 32'h00000100); // offset 0.1
    axi.write(evg.REG_IDX_SEQ_GAP*4, 32'h00000010); // delay 16

    axi.write(evg.REG_IDX_SEQ_ADDR_CODE*4, 32'h800002ff); // offset 0.2, code 255 (EoS)
    axi.write(evg.REG_IDX_SEQ_ADDR_CODE*4, 32'h00000200); // offset 0.2
    axi.write(evg.REG_IDX_SEQ_GAP*4, 32'h00000000); // delay 0

    axi.write(evg.REG_IDX_CSR*4, 32'h00000001); // arm bank 0
    while(~evg.ospreyEVGsequencer_i.evgArmed[0])
        @(posedge evgClk);

    axi.read(evg.REG_IDX_CSR*4, 32'h00000010); // seq 0 armed

    axi.write(evg.REG_IDX_CSR*4, 32'h40000001); // soft trig bank 0

    while(~evg.ospreyEVGsequencer_i.evgActive)
        @(posedge evgClk);
    axi.read(evg.REG_IDX_CSR*4, 32'h00200000); // seq 0 active

    waitForEvent(8'h10);
    waitForEvent(8'h11);
    while(evg.ospreyEVGsequencer_i.evgActive)
        @(posedge evgClk);
    axi.read(evg.REG_IDX_CSR*4, 32'h00000000); // seq 0 idle
end
endtask

reg [9:0] evtLog [0:15];
reg [3:0] evtLogIn = 0;
reg [3:0] evtLogOut = 0;
wire [9:0] evtLogNext = evtLog[evtLogOut];

always @(posedge evgClk)
    if(evg.eventRequest) begin
        $display("Rx event 0x%02x", evg.eventCode);
        evtLogIn <= evtLogIn+1;
        evtLog[evtLogIn] = {1'b1, evg.eventCode};
    end

task resetEventLog;
begin
    reg [4:0] i;
    evtLogIn <= 0;
    evtLogOut <= 0;
    for(i = 0 ; i < 16 ; i = i + 1) begin
        $display("Reset %d", i);
        evtLog[i] <= 9'hxxx;
    end
end
endtask

task waitForEvent;
    input [7:0] code;
begin
    $display("Wait for event 0x%02x", code);
    @(posedge evgClk);
    while(evtLogIn==evtLogOut)
        @(posedge evgClk);
    `assert_eq(evtLog[evtLogOut], {1'b1, code});
    evtLogOut <= evtLogOut+1;
end
endtask

endmodule
