`timescale  1 ns / 1 ns
module test;

`define assert_eq(L, R) begin \
    $display("%s 0x%x === 0x%x", L===R ? "ok" : "not ok", L, R); \
    if(L!==R) $stop; \
end

reg sysClk = 0;
always #5 sysClk <= ~sysClk; // 100MHz

reg csrStrobe = 0; // active high
reg [31:0] GPIO_OUT;
wire lCLK;
wire lLE;
wire lDATA;

wire sCLK; // idle high
wire sCS; // active low
wire sMOSI;
reg [31:0] sMISOA;
reg [31:0] sMISOB;

wire [31:0] readback;

integer bitn = 0;
always @(negedge sCS)
    bitn <= 0;
always @(negedge sCLK)
    if(~sCS) begin
        bitn <= bitn+1;
        sMISOA <= {sMISOA[30:0], 1'bx};
        sMISOB <= {sMISOB[30:0], 1'bx};
    end

// output bit states
wire [5:0] bits = {lDATA, lLE, lCLK, sMOSI, sCS, sCLK};

ospreyRFIN #(
    .DEBUG("false"))
  ospreyRFIN (
    .sysClk(sysClk),
    .csrStrobe(csrStrobe),
    .GPIO_OUT(GPIO_OUT),
    .readback(readback),
    .RFIN_LMK01801_CLK(lCLK),
    .RFIN_LMK01801_LE(lLE),
    .RFIN_LMK01801_DATA(lDATA),
    .RFIN_ADS7253_CLK(sCLK),
    .RFIN_ADS7253_CSB(sCS),
    .RFIN_ADS7253_DIN(sMOSI),
    .RFIN_ADS7253_DOUTA(sMISOA[31]),
    .RFIN_ADS7253_DOUTB(sMISOB[31]));

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

    // TODO: initially adcStopped=1 ??
    gpio(8'h01); // stop
    while(~readback[0])
        @(posedge sysClk);
    @(posedge sysClk);

    `assert_eq(bits, 6'b000010); // sCS active low

    #10
    $display("uWire passthrough");
    gpio(8'b10000000); // lDATA
    `assert_eq(bits, 6'b100010);
    gpio(8'b01000000); // lLE
    `assert_eq(bits, 6'b010010);
    gpio(8'b00100000); // lCLK
    `assert_eq(bits, 6'b001010);
    gpio(0); // idle
    `assert_eq(bits, 6'b000010);

    $display("SPI passthrough");
    gpio(8'b00010000); // sMOSI
    @(posedge sysClk); // latency...
    @(posedge sysClk);
    `assert_eq(bits, 6'b000110);
    gpio(8'b00001000); // !sCS
    @(posedge sysClk);
    @(posedge sysClk);
    `assert_eq(bits, 6'b000000);
    gpio(8'b00000100); // sCLK
    @(posedge sysClk);
    @(posedge sysClk);
    `assert_eq(bits, 6'b000011);

    sMISOA[31] <= 1'b0;
    sMISOB[31] <= 1'b0;
    @(posedge sysClk);
    @(posedge sysClk);
    `assert_eq(readback[2:0], 3'b001);

    sMISOA[31] <= 1'b1;
    sMISOB[31] <= 1'b0;
    @(posedge sysClk);
    @(posedge sysClk);
    `assert_eq(readback[2:0], 3'b011);

    sMISOA[31] <= 1'b0;
    sMISOB[31] <= 1'b1;
    @(posedge sysClk);
    @(posedge sysClk);
    `assert_eq(readback[2:0], 3'b101);

    sMISOA[31] <= 1'bx;
    sMISOB[31] <= 1'bx;

    $display("ADC run");
    sMISOA <= 32'hxxxxbeef; // first 16 bits are sampling period
    sMISOB <= 32'hxxxxdead;
    gpio(8'b00000010); // adcStart
    @(negedge sCS);
    @(posedge sCS);
    @(posedge sysClk);
    `assert_eq(readback, 32'hdeadbeee); // bit 0 always 0 to indicate run mode
    @(posedge sysClk); // expect stability until next completion
    `assert_eq(readback, 32'hdeadbeee);

    sMISOA <= 32'hxxxxface;
    sMISOB <= 32'hxxxx1bad;
    @(negedge sCS);
    @(posedge sCS);
    @(posedge sysClk);
    `assert_eq(readback, 32'h1badface);
    @(posedge sysClk);
    `assert_eq(readback, 32'h1badface);

`ifdef __ICARUS__
    #10
    $finish();
`endif
end

task gpio;
    input [31:0] value;
begin
    @(negedge sysClk);
    GPIO_OUT <= value;
    csrStrobe <= 1;
    @(negedge sysClk);
    GPIO_OUT <= 32'hxxxxxxxx;
    csrStrobe <= 0;
end
endtask

endmodule
