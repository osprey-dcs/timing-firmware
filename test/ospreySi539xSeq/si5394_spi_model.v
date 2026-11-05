/*
 * Behavioural model of the Si5394 4-wire SPI port, for simulation only.
 *
 * - Commands: Set Address 0x00, Write Data 0x40, Read Data 0x80
 *   (16-bit frames, CSb high between frames).
 * - Paged register file: register 0x01 on every page is the page register.
 * - SDO changes TD2 = 12 ns after each SCLK falling edge.
 * - Checks datasheet Table 16 timing: SCLK high/low >= 20 ns (40% of a 50 ns
 *   period), CSb setup to the first SCLK rise >= 5 ns, SCLK fall to CSb rise
 *   >= 5 ns, CSb high between frames >= 95 ns. Violations are counted.
 */
`timescale 1ns / 1ps
module si5394_spi_model (
    input  wire csn,
    input  wire sclk,
    input  wire sdi,
    output reg  sdo
);
reg   [7:0] regs [0:4095];     // {page[3:0], addr[7:0]}
reg   [7:0] page = 8'h00;
reg   [7:0] addr_ptr = 8'h00;
reg  [15:0] shift = 16'h0;
integer     nbits = 0;
reg         reading = 1'b0;
reg   [7:0] rdbyte = 8'h00;

integer n_frames = 0, n_writes = 0, n_page_writes = 0, n_reads = 0;
integer n_violations = 0;
realtime t_cs_rise = -1000.0, t_cs_fall = 0.0, t_rise = 0.0, t_fall = 0.0;
realtime cs_high_last = 0.0;   // most recent CSb-high time between frames
reg      first_rise = 1'b0;

// Last register write, for the testbench to watch
event        wr_ev;
reg  [11:0]  wr_addr = 12'h0;
reg   [7:0]  wr_data = 8'h0;
realtime     wr_time = 0.0;

integer i;
initial begin
    for (i = 0 ; i < 4096 ; i = i + 1) regs[i] = 8'h00;
    sdo = 1'b0;
end

task violation(input [8*40-1:0] what, input real val);
    begin
        n_violations = n_violations + 1;
        if (n_violations <= 10)
            $display("[%0t] SPI TIMING VIOLATION: %0s (%0.1f ns)", $time, what, val);
    end
endtask

always @(negedge csn) begin
    if ($realtime - t_cs_rise < 95.0) violation("CSb high time < 95 ns", $realtime - t_cs_rise);
    cs_high_last = $realtime - t_cs_rise;
    t_cs_fall  = $realtime;
    nbits      = 0;
    reading    = 1'b0;
    first_rise = 1'b1;
end

always @(posedge sclk) begin
    if (!csn) begin
        if (first_rise) begin
            if ($realtime - t_cs_fall < 5.0) violation("CSb setup < 5 ns", $realtime - t_cs_fall);
            first_rise = 1'b0;
        end
        else if ($realtime - t_fall < 20.0) violation("SCLK low < 20 ns", $realtime - t_fall);
        shift = {shift[14:0], sdi};
        nbits = nbits + 1;
        if (nbits == 8 && shift[7:0] == 8'h80) begin
            reading = 1'b1;
            rdbyte  = (addr_ptr == 8'h01) ? page : regs[{page[3:0], addr_ptr}];
        end
    end
    t_rise = $realtime;
end

always @(negedge sclk) begin
    if (!csn) begin
        if ($realtime - t_rise < 20.0) violation("SCLK high < 20 ns", $realtime - t_rise);
        if (reading && nbits >= 8 && nbits < 16) begin
            sdo <= #12 rdbyte[7];
            rdbyte = {rdbyte[6:0], 1'b0};
        end
    end
    t_fall = $realtime;
end

always @(posedge csn) begin
    if ($realtime - t_fall < 5.0 && $realtime - t_cs_fall > 1.0)
        violation("SCLK fall to CSb rise < 5 ns", $realtime - t_fall);
    t_cs_rise = $realtime;
    if (nbits != 16) begin
        if ($realtime > 1.0) violation("frame not 16 bits", nbits);
    end
    else begin
        n_frames = n_frames + 1;
        case (shift[15:8])
        8'h00: addr_ptr = shift[7:0];
        8'h40: begin
            if (addr_ptr == 8'h01) begin
                page = shift[7:0];
                n_page_writes = n_page_writes + 1;
            end
            else begin
                regs[{page[3:0], addr_ptr}] = shift[7:0];
                n_writes = n_writes + 1;
            end
            wr_addr = {page[3:0], addr_ptr};
            wr_data = shift[7:0];
            wr_time = $realtime;
            -> wr_ev;
        end
        8'h80: n_reads = n_reads + 1;
        default: $display("[%0t] MODEL: unknown SPI command 0x%02x", $time, shift[15:8]);
        endcase
    end
    sdo <= #12 1'b0;
end
endmodule
