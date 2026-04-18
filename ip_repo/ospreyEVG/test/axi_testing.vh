/** @file axi_testing.vh
 *
 * Test client for AXI modules using IVerilog
 *
 * Selection from the 0 or 1 signal ordering variations using:
 * @code
 *   vvp ... my_tb.v +axiproto=0
 * @endcode
 *
 * Client operations
 * @code
 * `timescale  1 ns / 1 ns
 * module test;
 * `include "axi_testing.vh"
 * always #5 ACLK <= ~ACLK;
 * my dut (
 *   .s_axi_aclk(ACLK), // testing signal names from AMBA spec.
 *   ...
 * );
 * initial begin
 *   ...
 *   axi.read(32'h00000000, 32'hdeadbeef) // expect to read 0xdeadbeef from address 0
 *
 *   axi.write(32'h00001234, 32'deadbeef) // write to address 0x1234, expect BRESP success
 * end
 * endmodule
 * @endcode
 */

reg ACLK = 0;
reg ARESETn = 1;

reg [11:0] ARADDR;
reg ARVALID = 0;
wire ARREADY;

wire [31:0] RDATA;
wire [1:0] RRESP;
wire RVALID;
reg RREADY = 0;

reg [11:0] AWADDR;
reg AWVALID = 0;
wire AWREADY;

reg [31:0] WDATA;
reg WVALID = 0;
wire WREADY;

wire [1:0] BRESP;
wire BVALID;
reg BREADY = 0;

/* Refering to "AMBA® AXI™ and ACE™ Protocol Specification"
 * revision E, 22 Feb. 2013
 *
 * Principly A3.3.1 "Dependencies between channel handshake signals"
 * sub-sections "Read transaction dependencies"
 * and "Write transaction dependencies"
 */

generate if(1) begin : axi // private namespace

/* AXI master protocol variant
 *
 * 0 - Master waits for slave.
 *     "the master can wait for RVALID to be asserted before it asserts RREADY"
 *     "the master can wait for BVALID before asserting BREADY"
 * 1 - Master leads
 *     "the master can assert RREADY before RVALID is asserted."
 *     "the master can assert BREADY before BVALID is asserted."
 */
reg proto = 0;

initial begin
    if($value$plusargs("axiproto=%d", proto)) begin end
    $display("# Using AXI master protocol variant %d", proto);
    if(proto<0 || proto>1) begin
        $display("$  Invalid variant");
        $stop;
    end
end

// read channels

reg rdone = 1;
always @(posedge ACLK) begin
    if(ARVALID && ARREADY && RVALID) begin
        // "the slave must wait for both ARVALID and ARREADY to be asserted before
        // it asserts RVALID to indicate that valid data is available"
        $display("  axi_read premature RVALID");
        $stop;
    end
    if(ARVALID && ARREADY) begin
        ARVALID <= 0;
        ARADDR <= 32'hxxxxxxxx;
    end
    // "the master can wait for RVALID to be asserted before it asserts RREADY"
    if(~rdone && RVALID) begin
        RREADY <= 1;
        rdone <= 1;
    end else if(RVALID && RREADY) begin
        RREADY <= 0;
    end
end

// write channels

reg wdone = 1;
always @(posedge ACLK) begin
    if(AWVALID && AWREADY && BVALID) begin
        // "the slave must wait for both WVALID and WREADY to be asserted before asserting BVALID"
        $display("  axi_write premature BVALID");
        $stop;
    end
    if(AWVALID && AWREADY) begin
        AWVALID <= 0;
        AWADDR <= 32'hxxxxxxxx;
    end
    if(WVALID && WREADY) begin
        WVALID <= 0;
        WDATA <= 32'hxxxxxxxx;
    end
    // "the master can wait for BVALID before asserting BREADY"
    if(~wdone && BVALID) begin
        BREADY <= 1;
        wdone <= 1;
    end else if(BVALID && BREADY) begin
        BREADY <= 0;
    end
end

// AXI4LITE read transaction

task read_mask;
    input [31:0] addr;
    input [31:0] mask;
    input [31:0] expected;
begin
    $display("axi_reading 0x%x, mask 0x%x, expecting 0x%x", addr, mask, expected);

    @(negedge ACLK);

    ARADDR <= addr;
    // "the master must not wait for the slave to assert ARREADY before asserting ARVALID"
    ARVALID <= 1;

    case(axi.proto)
    0: axi.rdone <= 0;
    1: RREADY <= 1;
    endcase

    @(posedge ACLK);
    while(~(RVALID && RREADY))
        @(posedge ACLK);

    $display("  axi_read 0x%x, mask 0x%x, expected 0x%x, found 0x%x",
        addr, mask, expected, RDATA);
    if((RDATA&mask)!==(expected&mask)) begin
        $display("  Mis-match! 0x%x !== 0x%x", RDATA&mask, expected&mask);
        $stop;
    end else begin
        $display("  Ok");
    end
end
endtask

task read;
    input [31:0] addr;
    input [31:0] expected;
begin
    read_mask(addr, 32'hffffffff, expected);
end
endtask

// AXI4LITE write transaction
task write;
    input [31:0] addr, wdata;
begin
    $display("axi_writing 0x%x, value 0x%x", addr, wdata);

    AWADDR <= 32'hxxxxxxxx;
    WDATA <= 32'hxxxxxxxx;

    @(negedge ACLK);

    // " the master must not wait for the slave to assert AWREADY or WREADY before asserting
    //   AWVALID or WVALID"
    AWADDR <= addr;
    AWVALID <= 1;

    WDATA <= wdata;
    WVALID <= 1;

    case(axi.proto)
    0:axi.wdone <= 0;
    1:BREADY <= 1;
    endcase

    @(posedge ACLK);
    while(~(BVALID && BREADY))
        @(posedge ACLK);

    if(BRESP!=0) begin
        $display("  Error! %x", BRESP);
        $stop;
    end else begin
        $display("  Ok");
    end
end
endtask

end endgenerate // end private namespace
