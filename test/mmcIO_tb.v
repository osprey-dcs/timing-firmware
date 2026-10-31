`timescale  1 ns / 1 ns
module test;

`define assert_eq(L, R) begin \
    $display("%s 0x%x === 0x%x", L===R ? "ok" : "not ok", L, R); \
    if(!(L===R)) $stop; \
    end

reg sysClk = 0;
always #5 sysClk <= ~sysClk; // 100MHz

// SPI baud rate needs to be not more than 1/4th of sysClk
reg spiClk = 0;
always #73 spiClk <= ~spiClk;

reg csrStrobe = 0;
reg [31:0] GPIO_OUT;
wire [31:0] GPIO_IN;

reg  CSB = 1;
reg  SCLK;
reg  MOSI;
wire MISO;

mmcIO dut(
    .clk(sysClk),
    .csrStrobe(csrStrobe),
    .GPIO_OUT(GPIO_OUT),
    .status(GPIO_IN),
    .MMC_CSB(CSB),
    .MMC_SCLK(SCLK),
    .MMC_MOSI(MOSI),
    .MMC_MISO(MISO)
);

`ifdef __ICARUS__
initial begin
    #100000
    $display("Timeout!");
    $stop;
end
`endif

initial begin
`ifdef __ICARUS__
    string vcd;
    if($value$plusargs("vcd=%s", vcd)) begin
        $display("Dump to %s", vcd);
        $dumpfile(vcd);
        $dumpvars(0,test);
    end
`endif

//    mmio_write(32'h0120000);

    $display("# Begin push MAC+IP");
    spi_push16({dut.OPCODE_CONTROL, dut.CONTROL_ADDRLO_ENABLE_ETHERNET, 8'h0}); // disable FPGA Ethernet
    // MAC
    spi_push16({dut.OPCODE_NETWORK_CONFIG, 4'd0, 8'h11});
    spi_push16({dut.OPCODE_NETWORK_CONFIG, 4'd1, 8'h22});
    spi_push16({dut.OPCODE_NETWORK_CONFIG, 4'd2, 8'h33});
    spi_push16({dut.OPCODE_NETWORK_CONFIG, 4'd3, 8'h44});
    spi_push16({dut.OPCODE_NETWORK_CONFIG, 4'd4, 8'h55});
    spi_push16({dut.OPCODE_NETWORK_CONFIG, 4'd5, 8'h66});
    // IP
    spi_push16({dut.OPCODE_NETWORK_CONFIG, 4'd6, 8'd192});
    spi_push16({dut.OPCODE_NETWORK_CONFIG, 4'd7, 8'd168});
    spi_push16({dut.OPCODE_NETWORK_CONFIG, 4'd8, 8'd1});
    spi_push16({dut.OPCODE_NETWORK_CONFIG, 4'd9, 8'd2});
    spi_push16({dut.OPCODE_CONTROL, dut.CONTROL_ADDRLO_ENABLE_ETHERNET, 8'h1}); // enable FPGA Ethernet

    `assert_eq(dut.netConfigDPRAM[0], 8'h11)
    `assert_eq(dut.netConfigDPRAM[6], 8'd192)

    @(posedge spiClk); // wait at least 4 sysClk ticks
    @(posedge sysClk);
    `assert_eq(GPIO_IN[31], 1'b1) // enabled
    $display("# Complete push MAC+IP");

    $display("# Begin Read MAC+IP");
    // MAC
    mmio_write({4'h0, 12'd0, 16'h0});
    `assert_eq(GPIO_IN[8+:8], 8'h11)
    mmio_write({4'h0, 12'd1, 16'h0});
    `assert_eq(GPIO_IN[8+:8], 8'h22)
    mmio_write({4'h0, 12'd2, 16'h0});
    `assert_eq(GPIO_IN[8+:8], 8'h33)
    mmio_write({4'h0, 12'd3, 16'h0});
    `assert_eq(GPIO_IN[8+:8], 8'h44)
    mmio_write({4'h0, 12'd4, 16'h0});
    `assert_eq(GPIO_IN[8+:8], 8'h55)
    mmio_write({4'h0, 12'd5, 16'h0});
    `assert_eq(GPIO_IN[8+:8], 8'h66)
    // IP
    mmio_write({4'h0, 12'd6, 16'h0});
    `assert_eq(GPIO_IN[8+:8], 8'd192)
    mmio_write({4'h0, 12'd7, 16'h0});
    `assert_eq(GPIO_IN[8+:8], 8'd168)
    mmio_write({4'h0, 12'd8, 16'h0});
    `assert_eq(GPIO_IN[8+:8], 8'd1)
    mmio_write({4'h0, 12'd9, 16'h0});
    `assert_eq(GPIO_IN[8+:8], 8'd2)
    $display("# Complete Read MAC+IP");

    $display("# Push MGT mailbox");
    mmio_write({4'h8, 12'h020, 8'h0, 8'hc3});
    @(posedge sysClk);
    `assert_eq(GPIO_IN[7:0], 8'hc3)

    $display("# Read MGT mailbox");
    spi_push16({dut.OPCODE_CONTROL, dut.CONTROL_ADDRLO_SET_ADDRHI, 8'h02}); // set page
    spi_mbox_read(4'h0, 8'hc3);

`ifdef __ICARUS__
    #10
    $finish();
`endif
end

task mmio_write;
    input [31:0] value;
begin
    @(negedge sysClk);
    GPIO_OUT <= value;
    csrStrobe <= 1;
    @(negedge sysClk);
    GPIO_OUT <= 32'hxxxxxxxx;
    csrStrobe <= 0;
    @(posedge sysClk);
end
endtask

task spi_shift16;
    input [15:0] din;
    output [15:0] dout;
begin
    integer i;
    CSB <= 1;
    SCLK <= 1;
    @(posedge spiClk);
    CSB <= 0;
    for(i=15; i >= 0 ; i = i -1) begin
        // setup
        SCLK <= 1;
        MOSI <= din[i];
        dout[i] <= MISO;
        @(posedge spiClk);
        SCLK <= 0;
        @(posedge spiClk);
    end
    CSB <= 1;
    SCLK <= 1;
    MOSI <= 1'bx;
end
endtask

task spi_push16;
    input [15:0] din;
begin
    reg [15:0] dout;
    spi_shift16(din, dout);
end
endtask

task spi_mbox_read;
    input [3:0] offset;
    input [7:0] value;
begin
    reg [15:0] dout;
    spi_shift16({dut.OPCODE_MAILBOX_READ, offset, 8'hxx}, dout);
    `assert_eq(dout[7:0], value)
end
endtask

endmodule
