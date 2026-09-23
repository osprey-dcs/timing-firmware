`timescale  1 ns / 1 ns
module test;

`include "../axi_testing.vh"

`define assert_eq(L, R) \
    $display("%s 0x%x === 0x%x", L===R ? "ok" : "not ok", L, R); \
    if(L!==R) $stop

reg evgClk = 1;
always #4 evgClk <= ~evgClk; // 125MHz

reg ppsMarker_a = 0;
reg [15:0] hwInputs_a = 0;

always #5 ACLK <= ~ACLK; // 100MHz

ospreyEVG_v1_0 #(
    .EVGCLK_FREQUENCY(125000000),
    .INPUT_COUNT(16),
    .TIMER_COUNT(2),
    .RX_COUNT(1),
    .HW_TRIGGER_COUNT(16),
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
    .evgTxChars(),
    .evgTxCharIsK(),

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

    start_case("test_config");
    test_config();
    start_case("test_timer");
    test_timer();
    start_case("test_hwInput");
    test_hwInput();
    start_case("test_dbus");
    test_dbus();
    start_case("test_swEvent");
    test_swEvent();
    start_case("test_seq");
    test_seq();
    start_case("test_seq_timer");
    test_seq_timer();

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
    axi.read(evg.REG_IDX_CONFIG*4, 32'ha01B2210);
    axi.read(evg.REG_IDX_CSR*4, 32'h00000000);
end
endtask

task test_timer;
begin
    axi.write(evg.REG_IDX_TIMER_CONFIG_BASE*4 + (0<<3) + 4, 32'h0000000b); // load countdown
    axi.read (evg.REG_IDX_TIMER_CONFIG_BASE*4 + (0<<3) + 4, 32'h0000000b);
    axi.write(evg.REG_IDX_TIMER_CONFIG_BASE*4 + (0<<3) + 0, 32'h00000064); // event 100
    axi.read (evg.REG_IDX_TIMER_CONFIG_BASE*4 + (0<<3) + 0, 32'h00000064);
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
    axi.write(evg.REG_IDX_HW_TRIGGER_COUNT*4, {16'h0, 8'd1, 8'h0});
    axi.read (evg.REG_IDX_HW_TRIGGER_COUNT*4, {16'h0, 8'd1, 8'h0});
    axi.write(evg.REG_IDX_HW_TRIGGER_CONFIG*4, {16'h0000, 7'd1, 1'b0, 8'd100}); // 2nd input, rising, event 100
    axi.write(evg.REG_IDX_HW_TRIGGER_CONFIG*4, {16'h0000, 7'd1, 1'b1, 8'd101}); // 2nd input, falling, event 101
    `assert_eq(evg.hwTriggerEnables, 16'h000c); // ??

    hwInputs_a[1] <= 1'b1;
    waitForEvent(8'd100);
    hwInputs_a[1] <= 1'b0;
    waitForEvent(8'd101);

    axi.read (evg.REG_IDX_HW_TRIGGER_COUNT*4, {16'h0, 8'd1, 8'h1});

    axi.write(evg.REG_IDX_HW_TRIGGER_CONFIG*4, {16'h0000, 7'd1, 1'b0, 8'd0}); // 2nd input, rising, disable
    hwInputs_a[1] <= 1'b1;
    @(posedge evgClk);
    hwInputs_a[1] <= 1'b0;
    waitForEvent(8'd101);

    axi.read (evg.REG_IDX_HW_TRIGGER_COUNT*4, {16'h0, 8'd1, 8'h2});

    axi.write(evg.REG_IDX_HW_TRIGGER_CONFIG*4, {16'h0000, 7'd1, 1'b1, 8'd0}); // 2nd input, falling, disable
end
endtask

task test_dbus;
begin
    $display("# Initial DBus mapped to zero");
    `assert_eq(evg.evgDistributedBus, 8'h00);
    hwInputs_a <= 8'b11111111;
    @(posedge evgClk);
    @(posedge evgClk);
    `assert_eq(evg.evgDistributedBus, 8'h00);

    $display("# DBus map bit 0 <- input 0 (1st input)");
    axi.write(evg.REG_IDX_DBUS_MAP*4, 32'h80000001);
    axi.read (evg.REG_IDX_DBUS_MAP*4, 32'h00000001);
    `assert_eq(evg.dbusMap[0], 1);
    `assert_eq(evg.evgDistributedBus, 8'h01);
    hwInputs_a <= 8'b11111110;
    @(posedge evgClk);
    @(posedge evgClk);
    @(posedge evgClk);
    @(posedge evgClk);
    `assert_eq(evg.evgDistributedBus, 8'h00);
    axi.write(evg.REG_IDX_DBUS_MAP*4, 32'h80000000);
    `assert_eq(evg.dbusMap[0], 0);

    $display("# DBus map bit 1 <- input 2 (third input)");
    axi.write(evg.REG_IDX_DBUS_MAP*4, 32'h81000003);
    axi.read (evg.REG_IDX_DBUS_MAP*4, 32'h01000003);
    `assert_eq(evg.dbusMap[1], 3);
    hwInputs_a <= 8'b00000100;
    @(posedge evgClk);
    @(posedge evgClk);
    @(posedge evgClk);
    @(posedge evgClk);
    `assert_eq(evg.evgDistributedBus, 8'h02);
    axi.write(evg.REG_IDX_DBUS_MAP*4, 32'h81000000);
    `assert_eq(evg.dbusMap[1], 0);

    hwInputs_a <= 8'h00;
end
endtask

task test_swEvent;
begin
    axi.write(evg.REG_IDX_SW_EVENT*4, 8'h14);
    waitForEvent(8'h14);
    axi.write(evg.REG_IDX_SW_EVENT*4, 8'h00);
    // no event queued
    axi.write(evg.REG_IDX_SW_EVENT*4, 8'h15);
    waitForEvent(8'h15);
end
endtask

task test_seq;
begin
    evg.ospreyEVGsequencer_i.trigCountE <= 0; // zero trigger counters

    // BANK.OFFSET
    axi.write(evg.REG_IDX_SEQ_ADDR_CODE*4, 32'h80000010); // offset 0.0, code 16
    axi.read (evg.REG_IDX_SEQ_ADDR_CODE*4, 32'h00000010); // offset 0.0
    axi.write(evg.REG_IDX_SEQ_GAP*4, 32'h00000040); // delay 64
    axi.read (evg.REG_IDX_SEQ_GAP*4, 32'h00000040);

    axi.write(evg.REG_IDX_SEQ_ADDR_CODE*4, 32'h80000111); // offset 0.1, code 17
    axi.read (evg.REG_IDX_SEQ_ADDR_CODE*4, 32'h00000111);
    axi.write(evg.REG_IDX_SEQ_GAP*4, 32'h00000010); // delay 16
    axi.read (evg.REG_IDX_SEQ_GAP*4, 32'h00000010);

    axi.write(evg.REG_IDX_SEQ_ADDR_CODE*4, 32'h800002ff); // offset 0.2, code 255 (EoS)
    axi.write(evg.REG_IDX_SEQ_GAP*4, 32'h00000000); // delay 0

    $display("# Arming");
    axi.write(evg.REG_IDX_CSR*4, 32'h10000001); // arm bank 0
    while(~evg.ospreyEVGsequencer_i.evgArmed[0])
        @(posedge evgClk);

    axi.read(evg.REG_IDX_CSR*4, 32'h00000010); // seq 0 armed
    axi.read(evg.REG_IDX_SEQ_COUNT*4, 32'h00000000); // trig. count 0

    $display("# Trigger");
    axi.write(evg.REG_IDX_CSR*4, 32'h40000001); // soft trig bank 0

    while(~evg.ospreyEVGsequencer_i.evgActive)
        @(posedge evgClk);
    axi.read(evg.REG_IDX_CSR*4, 32'h00100000); // seq 0 active

    waitForEvent(8'h10);
    waitForEvent(8'h11);
    while(evg.ospreyEVGsequencer_i.evgActive)
        @(posedge evgClk);
    axi.read(evg.REG_IDX_CSR*4, 32'h00000000); // seq 0 idle

    axi.read(evg.REG_IDX_SEQ_COUNT*4, 32'h00000001); // trig. count 1
end
endtask

task test_seq_timer;
begin
    evg.ospreyEVGsequencer_i.trigCountE <= 0; // zero trigger counters

    // BANK.OFFSET
    axi.write(evg.REG_IDX_SEQ_ADDR_CODE*4, 32'h80000020); // offset 0.0, code 32
    axi.write(evg.REG_IDX_SEQ_ADDR_CODE*4, 32'h00000000); // offset 0.0
    axi.write(evg.REG_IDX_SEQ_GAP*4, 32'h00000040); // delay 64

    axi.write(evg.REG_IDX_SEQ_ADDR_CODE*4, 32'h80000121); // offset 0.1, code 33
    axi.write(evg.REG_IDX_SEQ_ADDR_CODE*4, 32'h00000100); // offset 0.1
    axi.write(evg.REG_IDX_SEQ_GAP*4, 32'h00000010); // delay 16

    axi.write(evg.REG_IDX_SEQ_ADDR_CODE*4, 32'h800002ff); // offset 0.2, code 255 (EoS)
    axi.write(evg.REG_IDX_SEQ_ADDR_CODE*4, 32'h00000200); // offset 0.2
    axi.write(evg.REG_IDX_SEQ_GAP*4, 32'h00000000); // delay 0

    // configure timer 0
    axi.write(evg.REG_IDX_TIMER_CSR*4, 32'h00000001); // stop timer 0
    axi.write(evg.REG_IDX_TIMER_CONFIG_BASE*4 + (0<<3) + 4, 32'h0000000b); // load countdown
    axi.write(evg.REG_IDX_TIMER_CONFIG_BASE*4 + (0<<3) + 0, 32'h00000000); // event 0

    axi.write(evg.REG_IDX_CSR*4, 32'h20000001); // set bank 0 trigger on timer 0

    axi.write(evg.REG_IDX_CSR*4, 32'h10000001); // arm bank 0
    while(~evg.ospreyEVGsequencer_i.evgArmed[0])
        @(posedge evgClk);
    axi.read(evg.REG_IDX_CSR*4, 32'h00000010); // seq 0 armed

    axi.read(evg.REG_IDX_SEQ_COUNT*4, 32'h00000000); // trig. count 0

    axi.write(evg.REG_IDX_TIMER_CSR*4, 32'h00000003); // start timer 0

    while(~evg.ospreyEVGsequencer_i.evgActive)
        @(posedge evgClk);
    axi.read(evg.REG_IDX_CSR*4, 32'h00100000); // seq 0 active

    waitForEvent(8'h20);
    waitForEvent(8'h21);
    while(evg.ospreyEVGsequencer_i.evgActive)
        @(posedge evgClk);
    axi.read(evg.REG_IDX_CSR*4, 32'h00000000); // seq 0 idle

    axi.write(evg.REG_IDX_TIMER_CSR*4, 32'h00000001); // stop timer 0

    axi.read(evg.REG_IDX_SEQ_COUNT*4, 32'h00000001); // trig. count 1

    $display("Set normal trigger");
    axi.write(evg.REG_IDX_CSR*4, 32'h60000001); // bank 0 normal trigger
    axi.write(evg.REG_IDX_CSR*4, 32'h10000001); // arm bank 0
    axi.write(evg.REG_IDX_TIMER_CSR*4, 32'h00000003); // start timer 0

    while(~evg.ospreyEVGsequencer_i.evgActive)
        @(posedge evgClk);
    axi.read(evg.REG_IDX_CSR*4, 32'h01100010); // seq 0 normal, active, and armed

    $display("rep. 1");
    waitForEvent(8'h20);
    waitForEvent(8'h21);
    $display("rep. 2");
    waitForEvent(8'h20);
    $display("switch to single trigger while running");
    axi.write(evg.REG_IDX_CSR*4, 32'h60000100); // bank 0 single trigger
    axi.read (evg.REG_IDX_CSR*4, 32'h00100000); // seq 0 active
    waitForEvent(8'h21);

    axi.read(evg.REG_IDX_CSR*4, 32'h00000000); // seq 0 idle

    while(evg.ospreyEVGsequencer_i.evgActive)
        @(posedge evgClk);

    axi.read (evg.REG_IDX_CSR*4, 32'h00000000); // seq 0 idle

    axi.read(evg.REG_IDX_SEQ_COUNT*4, 32'h00000003); // trig. count 1
end
endtask

reg [8:0] evtLog [0:15];
reg [3:0] evtLogIn = 0;
reg [3:0] evtLogOut = 0;

always @(posedge evgClk)
    if(evg.eventRequest) begin
        $display("# Rx event 0x%02x", evg.eventCode);
        evtLogIn <= evtLogIn+1;
        evtLog[evtLogIn] = {1'b1, evg.eventCode};
    end

task resetEventLog;
begin
    reg [4:0] i;
    evtLogIn <= 0;
    evtLogOut <= 0;
    for(i = 0 ; i < 16 ; i = i + 1) begin
        $display("# Reset %d", i);
        evtLog[i] <= 9'hxxx;
    end
end
endtask

task waitForEvent;
    input [7:0] code;
begin
    $display("# Wait for event 0x%02x", code);
    @(posedge evgClk);
    while(evtLogIn==evtLogOut)
        @(posedge evgClk);
    `assert_eq(evtLog[evtLogOut], {1'b1, code});
    evtLogOut <= evtLogOut+1;
end
endtask

endmodule
