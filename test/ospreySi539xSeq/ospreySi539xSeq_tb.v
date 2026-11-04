/*
 * Testbench for ospreySi539xSeq.
 *   iverilog -g2012 -o tb ospreySi539xSeq_tb.v ospreySi539xSeq.v si5394_spi_model.v
 *   vvp tb
 */
`timescale 1ns / 1ps
module ospreySi539xSeq_tb;

reg clk = 0, resetn = 0;
always #5 clk = !clk;   // 100 MHz

// AXI4-Lite master signals
reg  [12:0] awaddr = 0;  reg awvalid = 0;  wire awready;
reg  [31:0] wdata  = 0;  reg wvalid  = 0;  wire wready;
wire  [1:0] bresp;       wire bvalid;      reg  bready = 1;
reg  [12:0] araddr = 0;  reg arvalid = 0;  wire arready;
wire [31:0] rdata;       wire [1:0] rresp; wire rvalid; reg rready = 1;

wire csn, sclk, mosi, miso, rstn, clkbuf_oen, lvlshift_oen;
reg  pin_lol = 1'b0, pin_los = 1'b1, pin_intr = 1'b1;

ospreySi539xSeq dut (
    .S_AXI_ACLK(clk), .S_AXI_ARESETN(resetn),
    .S_AXI_AWADDR(awaddr), .S_AXI_AWPROT(3'b0), .S_AXI_AWVALID(awvalid), .S_AXI_AWREADY(awready),
    .S_AXI_WDATA(wdata), .S_AXI_WSTRB(4'hF), .S_AXI_WVALID(wvalid), .S_AXI_WREADY(wready),
    .S_AXI_BRESP(bresp), .S_AXI_BVALID(bvalid), .S_AXI_BREADY(bready),
    .S_AXI_ARADDR(araddr), .S_AXI_ARPROT(3'b0), .S_AXI_ARVALID(arvalid), .S_AXI_ARREADY(arready),
    .S_AXI_RDATA(rdata), .S_AXI_RRESP(rresp), .S_AXI_RVALID(rvalid), .S_AXI_RREADY(rready),
    .spi_csn(csn), .spi_sclk(sclk), .spi_mosi(mosi), .spi_miso(miso),
    .chip_rstn(rstn), .clkbuf_oen(clkbuf_oen), .lvlshift_oen(lvlshift_oen),
    .pin_lol(pin_lol), .pin_los_xaxb(pin_los), .pin_intr(pin_intr));

si5394_spi_model chip (.csn(csn), .sclk(sclk), .sdi(mosi), .sdo(miso));

// Register offsets
localparam ID = 13'h1000, CONTROL = 13'h1004, STATUS = 13'h1008, SCLK_DIV = 13'h100C,
           SEQ_INDEX = 13'h1010, POLL_COUNT = 13'h1014, POLL_BASE = 13'h1100;

integer errors = 0, checks = 0;
task check(input cond, input [8*72-1:0] msg);
    begin
        checks = checks + 1;
        if (!cond) begin errors = errors + 1; $display("  FAIL: %0s", msg); end
        else             $display("  ok:   %0s", msg);
    end
endtask

// ---------------------------------------------------------------- AXI tasks
task axi_write(input [12:0] a, input [31:0] d);
    reg aw_done, w_done;
    begin
        @(posedge clk); #1;
        awaddr = a; wdata = d; awvalid = 1; wvalid = 1; aw_done = 0; w_done = 0;
        while (!(aw_done && w_done)) begin
            @(posedge clk);
            if (awvalid && awready) aw_done = 1;
            if (wvalid && wready)   w_done  = 1;
            #1;
            if (aw_done) awvalid = 0;
            if (w_done)  wvalid  = 0;
        end
        @(posedge clk); while (!bvalid) @(posedge clk);
        #1;
    end
endtask

task axi_read(input [12:0] a, output [31:0] d);
    begin
        @(posedge clk); #1;
        araddr = a; arvalid = 1;
        @(posedge clk); while (!arready) @(posedge clk);
        #1 arvalid = 0;
        @(posedge clk); while (!rvalid) @(posedge clk);
        d = rdata;
        #1;
    end
endtask

// Command encoders
function [31:0] c_write(input [11:0] a, input [7:0] d); c_write = {4'd1, a, 8'h00, d}; endfunction
function [31:0] c_read (input [11:0] a, input [7:0] e); c_read  = {4'd2, a, 8'h00, e}; endfunction
function [31:0] c_delay(input [27:0] clocks);           c_delay = {4'd3, clocks};      endfunction
function [31:0] c_page (input [7:0] pg);                c_page  = {4'd1, 12'h001, 8'h00, pg}; endfunction
localparam [31:0] C_END = 32'd0;

reg [31:0] v, v2;
task start_seq;   // read-modify-write CONTROL to set SEQ_GO
    begin axi_read(CONTROL, v); axi_write(CONTROL, v | 32'h1); end
endtask
task wait_seq_done;
    begin
        v = 0;
        while (!v[1]) axi_read(STATUS, v);
    end
endtask

// --------------------------------------------- watch for sequence vs poll overlap
integer overlap_errors = 0;
reg     watch_sticky = 0;
always @(chip.wr_ev) begin
    if (watch_sticky && chip.wr_addr == 12'h011 && dut.poll_busy) begin
        overlap_errors = overlap_errors + 1;
        $display("[%0t] ERROR: sequence write while a poll pass is running", $time);
    end
end

// Setup sequence used in test 2, verify sequence used in test 3
localparam NSETUP = 26, NVERIFY = 14;
reg [31:0] setup  [0:NSETUP-1];
reg [31:0] verify [0:NVERIFY-1];
integer i, n, mismatches, t_delay_start, t_delay_end;
realtime t0, t1;

initial begin
    if ($test$plusargs("vcd")) begin
        $dumpfile("ospreySi539xSeq_tb.vcd");
        $dumpvars(0, ospreySi539xSeq_tb);
    end

    // Status registers the model will report
    chip.regs[12'h00C] = 8'h00;  chip.regs[12'h00D] = 8'h0E;  chip.regs[12'h00E] = 8'h22;
    chip.regs[12'h00F] = 8'h00;  chip.regs[12'h011] = 8'h02;  chip.regs[12'h012] = 8'h0E;
    chip.regs[12'h013] = 8'h22;  chip.regs[12'h014] = 8'h20;  chip.regs[12'h507] = 8'h40;
    chip.regs[12'h53F] = 8'h02;

    repeat (5) @(posedge clk);
    resetn = 1;
    repeat (5) @(posedge clk);

    $display("\n=== 1. Reset state and registers   [t = %0.1f us]", $realtime / 1000.0);
    axi_read(ID, v);        check(v == 32'h53690100, "ID = 0x53690100 (\"Si\" v1.00)");
    axi_read(CONTROL, v);   check(v == 32'h00000700, "CONTROL reset = 0x700 (reset, outputs disabled)");
    check(rstn == 0 && clkbuf_oen == 1 && lvlshift_oen == 1, "chip pins: RSTb low, both OEs disabled");
    axi_read(STATUS, v);    check(v[2:0] == 3'b000, "STATUS idle");
    check(v[10:8] == 3'b110, "STATUS pins [10:8] = INTR 1, LOS 1, LOL 0");
    axi_read(SCLK_DIV, v);  check(v == 5, "SCLK_DIV reset = 5");
    axi_write(CONTROL, 32'h0000_0200);   // release reset, enable level shifters
    axi_read(CONTROL, v);   check(v == 32'h00000200, "CONTROL = 0x200 after write");
    check(rstn == 1 && clkbuf_oen == 1 && lvlshift_oen == 0, "chip pins follow CONTROL");

    $display("\n=== 2. Setup sequence (explicit page writes, 20 us delay)   [t = %0.1f us]", $realtime / 1000.0);
    setup[0]  = c_page(8'h0B);            setup[1]  = c_write(12'hB24, 8'hC0);
    setup[2]  = c_write(12'hB25, 8'h00);  setup[3]  = c_page(8'h05);
    setup[4]  = c_write(12'h540, 8'h01);  setup[5]  = c_delay(28'd2000);   // 20 us at 100 MHz
    setup[6]  = c_page(8'h00);            setup[7]  = c_write(12'h006, 8'h00);
    setup[8]  = c_write(12'h007, 8'h11);  setup[9]  = c_write(12'h008, 8'h22);
    setup[10] = c_page(8'h02);            setup[11] = c_write(12'h208, 8'h05);
    setup[12] = c_write(12'h209, 8'h06);  setup[13] = c_page(8'h03);
    setup[14] = c_write(12'h302, 8'h33);  setup[15] = c_page(8'h05);
    setup[16] = c_write(12'h515, 8'h44);  setup[17] = c_write(12'h514, 8'h01);
    setup[18] = c_page(8'h00);            setup[19] = c_write(12'h01C, 8'h01);
    setup[20] = c_page(8'h05);            setup[21] = c_write(12'h540, 8'h00);
    setup[22] = c_page(8'h0B);            setup[23] = c_write(12'hB24, 8'hC3);
    setup[24] = c_write(12'hB25, 8'h02);  setup[25] = C_END;
    for (i = 0 ; i < NSETUP ; i = i + 1) axi_write(i*4, setup[i]);
    axi_read(13'h0004, v);  check(v == setup[1], "sequence memory read-back");

    n = chip.n_page_writes;
    start_seq;
    axi_read(STATUS, v);    check(v[0] == 1, "SEQ_BUSY set right after SEQ_GO");
    // time the DELAY: from the write of 0x540=01 to the write of 0x006
    @(chip.wr_ev); while (!(chip.wr_addr == 12'h540 && chip.wr_data == 8'h01)) @(chip.wr_ev);
    t0 = chip.wr_time;
    @(negedge csn);          // first frame after the DELAY entry
    t1 = $realtime;
    wait_seq_done;
    check(v[0] == 0 && v[1] == 1, "SEQ_DONE set, SEQ_BUSY cleared");
    $display("        delay measured: %0.3f us (CSb high to next CSb low)", (t1 - t0) / 1000.0);
    check((t1 - t0) >= 20000.0 && (t1 - t0) < 20500.0, "DELAY of 2000 clocks lasts 20 us");
    axi_read(SEQ_INDEX, v); check(v == 25, "SEQ_INDEX = 25 (the END entry)");
    check(chip.n_page_writes - n == 9, "page register written only by the 9 explicit page entries");
    check(chip.n_frames == 2 * 24, "every WRITE is exactly 2 SPI frames (24 writes, 48 frames)");
    check(chip.regs[12'hB24] == 8'hC3 && chip.regs[12'h007] == 8'h11 && chip.regs[12'h209] == 8'h06
          && chip.regs[12'h302] == 8'h33 && chip.regs[12'h515] == 8'h44, "chip registers hold written values");

    $display("\n=== 3. Verify pass (READ entries, MicroBlaze-style compare)   [t = %0.1f us]", $realtime / 1000.0);
    verify[0]  = c_page(8'h00);           verify[1]  = c_read(12'h006, 8'h00);
    verify[2]  = c_read(12'h007, 8'h12);  // wrong on purpose
    verify[3]  = c_read(12'h008, 8'h22);  verify[4]  = c_page(8'h02);
    verify[5]  = c_read(12'h208, 8'h05);  verify[6]  = c_read(12'h209, 8'h06);
    verify[7]  = c_page(8'h03);           verify[8]  = c_read(12'h302, 8'h33);
    verify[9]  = c_page(8'h05);           verify[10] = c_read(12'h515, 8'h44);
    verify[11] = c_read(12'h501, 8'h05);  // reading the page register itself
    verify[12] = C_END;                   verify[13] = C_END;
    for (i = 0 ; i < NVERIFY ; i = i + 1) axi_write(i*4, verify[i]);
    start_seq; wait_seq_done;
    mismatches = 0;
    for (i = 0 ; i < NVERIFY ; i = i + 1) begin
        axi_read(i*4, v);
        if (v[31:28] == 4'd2 && v[15:8] != v[7:0]) begin
            mismatches = mismatches + 1;
            $display("        entry %0d: reg 0x%03x read 0x%02x expected 0x%02x", i, v[27:16], v[15:8], v[7:0]);
        end
    end
    check(mismatches == 1, "exactly one mismatch found (the deliberate one at 0x007)");
    axi_read(1*4, v);       check(v[31:16] == {4'd2, 12'h006} && v[7:0] == 8'h00, "READ word keeps opcode/address/expected");

    $display("\n=== 4. Polling: status registers with spread-out delays   [t = %0.1f us]", $realtime / 1000.0);
    axi_write(POLL_BASE + 4*0,  c_page(8'h00));       axi_write(POLL_BASE + 4*1,  c_read(12'h00C, 0));
    axi_write(POLL_BASE + 4*2,  c_delay(28'd200));     axi_write(POLL_BASE + 4*3,  c_read(12'h00D, 0));
    axi_write(POLL_BASE + 4*4,  c_read(12'h00E, 0));  axi_write(POLL_BASE + 4*5,  c_read(12'h00F, 0));
    axi_write(POLL_BASE + 4*6,  c_read(12'h011, 0));  axi_write(POLL_BASE + 4*7,  c_read(12'h012, 0));
    axi_write(POLL_BASE + 4*8,  c_read(12'h013, 0));  axi_write(POLL_BASE + 4*9,  c_read(12'h014, 0));
    axi_write(POLL_BASE + 4*10, c_page(8'h05));       axi_write(POLL_BASE + 4*11, c_read(12'h507, 0));
    axi_write(POLL_BASE + 4*12, c_read(12'h53F, 0));  axi_write(POLL_BASE + 4*13, c_delay(28'd1000));
    axi_write(POLL_BASE + 4*14, C_END);
    axi_read(CONTROL, v); axi_write(CONTROL, v | 32'h2);   // POLL_EN
    v2 = 0; while (v2 < 2) axi_read(POLL_COUNT, v2);
    axi_read(STATUS, v);    check(v[0] == 0, "SEQ_BUSY stays low during polling");
    axi_read(POLL_BASE + 4*1,  v); check(v[15:8] == 8'h00 && v[27:16] == 12'h00C, "poll 0x000C = 0x00");
    axi_read(POLL_BASE + 4*3,  v); check(v[15:8] == 8'h0E, "poll 0x000D = 0x0E (LOS on IN1-3)");
    axi_read(POLL_BASE + 4*4,  v); check(v[15:8] == 8'h22, "poll 0x000E = 0x22 (LOL, HOLD)");
    axi_read(POLL_BASE + 4*8,  v); check(v[15:8] == 8'h22, "poll 0x0013 = 0x22 (sticky LOL, HOLD)");
    axi_read(POLL_BASE + 4*11, v); check(v[15:8] == 8'h40, "poll 0x0507 = 0x40 (IN_ACTV = 1)");
    axi_read(POLL_BASE + 4*12, v); check(v[15:8] == 8'h02, "poll 0x053F = 0x02");
    // Chip locks: live LOL/HOLD clear
    chip.regs[12'h00E] = 8'h00;
    axi_read(POLL_COUNT, v); v2 = v; while (v2 < v + 2) axi_read(POLL_COUNT, v2);
    axi_read(POLL_BASE + 4*4, v); check(v[15:8] == 8'h00, "poll sees LOL clear (0x000E = 0x00)");

    $display("\n=== 5. SEQ_GO while polling: pass finishes first, then the sequence   [t = %0.1f us]", $realtime / 1000.0);
    // The poll pass leaves the chip on page 5, so this sequence must set page 0 first
    axi_write(0*4, c_page(8'h00));
    axi_write(1*4, c_write(12'h011, 8'h00));  axi_write(2*4, c_write(12'h012, 8'h00));
    axi_write(3*4, c_write(12'h013, 8'h00));  axi_write(4*4, c_write(12'h014, 8'h00));
    axi_write(5*4, C_END);
    watch_sticky = 1;
    // issue GO in the middle of a pass
    @(posedge clk); while (!(dut.poll_busy && dut.poll_index == 6)) @(posedge clk);
    axi_read(POLL_COUNT, v2);
    start_seq;
    axi_read(STATUS, v);   check(v[0] == 1 && v[2] == 1, "SEQ_BUSY high at once, poll pass still running");
    wait_seq_done;
    watch_sticky = 0;
    check(overlap_errors == 0, "no sequence SPI traffic while the poll pass was running");
    axi_read(POLL_COUNT, v); check(v == v2 + 1, "the interrupted pass completed (POLL_COUNT + 1)");
    check(chip.regs[12'h011] == 0 && chip.regs[12'h013] == 0, "sticky flags cleared by the sequence");
    axi_read(POLL_COUNT, v); v2 = v; while (v2 < v + 2) axi_read(POLL_COUNT, v2);
    axi_read(POLL_BASE + 4*8, v); check(v[15:8] == 8'h00, "polling resumed and sees 0x0013 cleared");

    $display("\n=== 6. Clearing POLL_EN mid-pass lets the pass finish   [t = %0.1f us]", $realtime / 1000.0);
    @(posedge clk); while (!(dut.poll_busy && dut.poll_index == 4)) @(posedge clk);
    axi_read(POLL_COUNT, v2);
    axi_read(CONTROL, v); axi_write(CONTROL, v & ~32'h2);
    axi_read(STATUS, v);   check(v[2] == 1, "POLL_BUSY still high right after clearing POLL_EN");
    while (v[2]) axi_read(STATUS, v);
    axi_read(POLL_COUNT, v); check(v == v2 + 1, "final pass completed (POLL_COUNT + 1)");
    #50000;
    axi_read(POLL_COUNT, v2); check(v2 == v, "no further passes after POLL_EN cleared");

    $display("\n=== 7. SCLK_DIV and SPI timing   [t = %0.1f us]", $realtime / 1000.0);
    check(chip.n_violations == 0, "no SPI timing violations at SCLK_DIV = 5 (10 MHz)");
    axi_write(SCLK_DIV, 3);    // 30 ns half period, 16.7 MHz
    axi_write(0, c_page(8'h00));
    axi_write(4, c_write(12'h007, 8'hA5)); axi_write(8, c_read(12'h007, 8'hA5)); axi_write(12, C_END);
    start_seq; wait_seq_done;
    axi_read(8, v);           check(v[15:8] == 8'hA5, "write/read at SCLK_DIV = 3 works");
    check(chip.n_violations == 0, "no SPI timing violations at SCLK_DIV = 3 (16.7 MHz)");
    n = chip.n_violations;
    axi_write(SCLK_DIV, 1);   // 10 ns half period, 50 MHz: out of spec on purpose
    start_seq; wait_seq_done;
    check(chip.n_violations > n, "model flags SCLK_DIV = 1 (50 MHz) as out of spec");
    axi_write(SCLK_DIV, 5);

    $display("\n=== 8. Sequence with no END stops at the last entry   [t = %0.1f us]", $realtime / 1000.0);
    for (i = 0 ; i < 1024 ; i = i + 1) axi_write(i*4, c_delay(28'd0));
    start_seq; wait_seq_done;
    axi_read(SEQ_INDEX, v);  check(v == 1023, "SEQ_INDEX = 1023 after running off the end");

    $display("\n=== 9. POLL_COUNT is 31 bits and wraps to 1   [t = %0.1f us]", $realtime / 1000.0);
    axi_read(CONTROL, v); axi_write(CONTROL, v | 32'h2);       // POLL_EN
    @(posedge clk); while (!(dut.poll_busy && dut.estate == 4'd6)) @(posedge clk);  // in a DELAY
    dut.poll_count = 31'h7FFFFFFE;
    axi_read(POLL_COUNT, v); check(v == 32'h7FFFFFFE, "POLL_COUNT reads 0x7FFFFFFE");
    while (v == 32'h7FFFFFFE) axi_read(POLL_COUNT, v);
    check(v == 32'h7FFFFFFF, "next pass: 0x7FFFFFFF (bit 31 never set)");
    while (v == 32'h7FFFFFFF) axi_read(POLL_COUNT, v);
    check(v == 32'h00000001, "next pass wraps to 1, not 0");
    axi_read(CONTROL, v); axi_write(CONTROL, v & ~32'h2);
    axi_read(STATUS, v); while (v[2]) axi_read(STATUS, v);

    $display("\n%0d checks, %0d failed", checks, errors);
    if (errors == 0) $display("PASS"); else $display("FAIL");
    $finish;
end

initial begin
    #20_000_000;
    $display("TIMEOUT");
    $finish;
end
endmodule
