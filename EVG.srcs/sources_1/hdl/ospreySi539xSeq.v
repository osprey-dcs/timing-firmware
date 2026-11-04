/*
 * MIT License
 *
 * Copyright (c) 2026 Osprey DCS
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
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

/*
 * ospreySi539xSeq -- SPI command sequencer for one Si539x jitter cleaner.
 *
 * Runs lists of register commands out of block RAM so the MicroBlaze does not
 * bit-bang SPI or spin through the 300 ms configuration wait. Instantiate
 * one per chip (the Trigger Output card has separate SPI pins for each).
 *
 * AXI4-Lite address map (byte offsets, 8 KB window):
 *   0x0000-0x0FFF  Sequence memory, R/W, 1024 x 32 command words
 *   0x1000         ID          R   engine type/version
 *   0x1004         CONTROL     R/W [0]  SEQ_GO   (self-clearing, reads 0)
 *                                  [1]  POLL_EN
 *                                  [8]  CHIP_RESET   1 = hold RSTb low      (reset: 1)
 *                                  [9]  CLKBUF_DIS   1 = clock outputs off  (reset: 1)
 *                                  [10] LVLSHIFT_DIS 1 = level shifters off (reset: 1)
 *   0x1008         STATUS      R   [0]  SEQ_BUSY  (set by SEQ_GO, cleared at END)
 *                                  [1]  SEQ_DONE  (set at END, cleared by SEQ_GO)
 *                                  [2]  POLL_BUSY (a poll pass is running)
 *                                  [8]  LOL pin      (active low, raw synchronized) 
 *                                  [9]  LOS_XAXB pin (active low, raw synchronized)
 *                                  [10] INTR pin     (active low, raw synchronized)
 *   0x100C         SCLK_DIV    R/W [15:0] SCLK half-period in clk cycles (0 -> 1),
 *                                         chip max is 20 MHz (so >= 3 at 100 MHz)
 *   0x1010         SEQ_INDEX   R   [9:0]  current sequence entry (or END location)
 *   0x1014         POLL_COUNT  R   [30:0] poll passes completed (rolls over to 1)
 *   0x1100-0x11FF  Poll memory, R/W, 64 x 32 command words
 *
 * Command word:
 *   [31:28] opcode   0 = END, 1 = WRITE, 2 = READ, 3 = DELAY (others = END)
 *   [27:24] ignored (software may record the page here)
 *   [23:16] register address within the current page
 *   [15:8]  READ result, written back into the word
 *   [7:0]   WRITE data, or the expected value for a READ (not used)
 *   DELAY:  [27:0] clock cycles of S_AXI_ACLK
 *
 * Behavior:
 *   - SEQ_GO (ignored while SEQ_BUSY) sets SEQ_BUSY at once. Any poll pass in
 *     progress runs to its END, delays included, then the sequence runs from
 *     entry 0 to END (or the last entry), which sets SEQ_DONE.
 *   - While POLL_EN is 1 and no sequence is pending, the poll memory runs from
 *     entry 0 to END repeatedly; POLL_COUNT increments after each pass.
 *     Clearing POLL_EN lets the current pass finish. Only change the poll
 *     memory while POLL_BUSY is 0.
 *   - The engine does not manage the page. The page register (0x01) is written
 *     like any other register, so every sequence and every poll program must
 *     start by writing it (otherwise, switching from sequence to poll or back
 *     inherits the previous page setting).
 *   - Do not write a memory while the engine may be running from it (busy flags).
 *   - Memories are written as whole 32-bit words (WSTRB is ignored).
 *   - Start a sequence with a read-modify-write of CONTROL so bits 8-10 are kept.
 *
 * SPI: 4-wire, mode 0 (SCLK idles low, data driven on the falling edge,
 * sampled by the chip on the rising edge), 16-bit frames with CSb high
 * between frames. MISO is sampled at the end of each SCLK high.
 * Each WRITE is Set Address {0x00,reg} then Write Data {0x40,data}; each READ
 * is Set Address {0x00,reg} then Read Data {0x80,xx}.
 */
`default_nettype none
module ospreySi539xSeq #(
    parameter integer SCLK_DIV_RESET = 5,         // 10 MHz SCLK at 100 MHz clk
    parameter integer CS_GAP_MIN     = 12,        // min CSb-high clk cycles (>= 95 ns)
    parameter [31:0]  ID_VALUE       = 32'h53690100 // "Si", version 1.00
    ) (
    input  wire        S_AXI_ACLK,
    input  wire        S_AXI_ARESETN,

    input  wire [12:0] S_AXI_AWADDR,
    input  wire  [2:0] S_AXI_AWPROT,
    input  wire        S_AXI_AWVALID,
    output wire        S_AXI_AWREADY,
    input  wire [31:0] S_AXI_WDATA,
    input  wire  [3:0] S_AXI_WSTRB,
    input  wire        S_AXI_WVALID,
    output wire        S_AXI_WREADY,
    output wire  [1:0] S_AXI_BRESP,
    output wire        S_AXI_BVALID,
    input  wire        S_AXI_BREADY,
    input  wire [12:0] S_AXI_ARADDR,
    input  wire  [2:0] S_AXI_ARPROT,
    input  wire        S_AXI_ARVALID,
    output wire        S_AXI_ARREADY,
    output wire [31:0] S_AXI_RDATA,
    output wire  [1:0] S_AXI_RRESP,
    output wire        S_AXI_RVALID,
    input  wire        S_AXI_RREADY,

    // Si539x SPI and control pins (tri-state them in the wrapper as needed)
    output reg         spi_csn  = 1'b1,
    output reg         spi_sclk = 1'b0,
    output reg         spi_mosi = 1'b0,
    input  wire        spi_miso,
    output wire        chip_rstn,     // to RSTb
    output wire        clkbuf_oen,    // clock buffer output enable (active low)
    output wire        lvlshift_oen,  // level shifter output enable (active low)
    input  wire        pin_lol,       // LOLb
    input  wire        pin_los_xaxb,  // LOS_XAXBb
    input  wire        pin_intr       // INTRb
);

localparam SEQ_DEPTH  = 1024;
localparam POLL_DEPTH = 64;

localparam [3:0] OP_END = 4'd0, OP_WRITE = 4'd1, OP_READ = 4'd2, OP_DELAY = 4'd3;

wire clk    = S_AXI_ACLK;
wire resetn = S_AXI_ARESETN;

//////////////////////////////////////////////////////////////////////////////
// Control and status registers
reg         poll_en      = 1'b0;
reg         chip_reset   = 1'b1;
reg         clkbuf_dis   = 1'b1;
reg         lvlshift_dis = 1'b1;
reg  [15:0] sclk_div     = SCLK_DIV_RESET;
reg         seq_go       = 1'b0;   // one-cycle request from an AXI write
reg         seq_busy     = 1'b0;
reg         seq_done     = 1'b0;
reg         poll_busy    = 1'b0;
reg   [9:0] seq_index    = 10'd0;
reg   [5:0] poll_index   = 6'd0;
reg  [30:0] poll_count   = 31'd0;

assign chip_rstn    = !chip_reset;
assign clkbuf_oen   = clkbuf_dis;
assign lvlshift_oen = lvlshift_dis;

(* ASYNC_REG = "TRUE" *) reg [2:0] pins_m = 3'b000, pins_s = 3'b000;
always @(posedge clk) begin
    pins_m <= {pin_intr, pin_los_xaxb, pin_lol};
    pins_s <= pins_m;
end

//////////////////////////////////////////////////////////////////////////////
// Memories: port A for AXI, port B for the engine
wire        axi_seq_we, axi_poll_we;
wire  [9:0] axi_seq_addr;
wire  [5:0] axi_poll_addr;
wire [31:0] axi_wdata;
wire [31:0] seq_douta, poll_douta;
wire [31:0] seq_doutb, poll_doutb;
reg         eng_we = 1'b0;
reg  [31:0] eng_wdata = 32'd0;
reg         ctx_poll = 1'b0;   // engine context: 0 = sequence, 1 = poll

ospreySi539xSeqRAM #(.AW(10)) seqRAM (
    .clk(clk),
    .wea(axi_seq_we), .addra(axi_seq_addr), .dina(axi_wdata), .douta(seq_douta),
    .web(eng_we && !ctx_poll), .addrb(seq_index), .dinb(eng_wdata), .doutb(seq_doutb));

ospreySi539xSeqRAM #(.AW(6)) pollRAM (
    .clk(clk),
    .wea(axi_poll_we), .addra(axi_poll_addr), .dina(axi_wdata), .douta(poll_douta),
    .web(eng_we && ctx_poll), .addrb(poll_index), .dinb(eng_wdata), .doutb(poll_doutb));

//////////////////////////////////////////////////////////////////////////////
// AXI4-Lite slave
reg         aw_have = 1'b0, w_have = 1'b0, bvalid_r = 1'b0;
reg  [12:0] aw_addr = 13'd0;
reg  [31:0] w_data  = 32'd0;
reg         rd_busy = 1'b0, rd_phase = 1'b0, rvalid_r = 1'b0;
reg  [12:0] rd_addr = 13'd0;
reg  [31:0] rdata_r = 32'd0;

wire do_write  = aw_have && w_have && !bvalid_r;
assign S_AXI_AWREADY = !aw_have;
assign S_AXI_WREADY  = !w_have;
assign S_AXI_BVALID  = bvalid_r;
assign S_AXI_BRESP   = 2'b00;
assign S_AXI_ARREADY = !rd_busy && !do_write;
assign S_AXI_RVALID  = rvalid_r;
assign S_AXI_RDATA   = rdata_r;
assign S_AXI_RRESP   = 2'b00;
wire rd_accept = S_AXI_ARVALID && S_AXI_ARREADY;

wire wr_seq  = do_write && (aw_addr[12] == 1'b0);
wire wr_reg  = do_write && (aw_addr[12:8] == 5'h10);
wire wr_poll = do_write && (aw_addr[12:8] == 5'h11);

assign axi_seq_we    = wr_seq;
assign axi_poll_we   = wr_poll;
assign axi_wdata     = w_data;
assign axi_seq_addr  = do_write ? aw_addr[11:2] : S_AXI_ARADDR[11:2];
assign axi_poll_addr = do_write ? aw_addr[7:2]  : S_AXI_ARADDR[7:2];

wire [31:0] control_rb = {21'd0, lvlshift_dis, clkbuf_dis, chip_reset,
                          6'd0, poll_en, 1'b0};
wire [31:0] status_rb  = {21'd0, pins_s, 5'd0, poll_busy, seq_done, seq_busy};

reg [31:0] rd_mux;
always @(*) begin
    if (rd_addr[12] == 1'b0)          rd_mux = seq_douta;
    else if (rd_addr[12:8] == 5'h11)  rd_mux = poll_douta;
    else if (rd_addr[12:8] == 5'h10) begin
        case (rd_addr[7:2])
        6'd0:    rd_mux = ID_VALUE;
        6'd1:    rd_mux = control_rb;
        6'd2:    rd_mux = status_rb;
        6'd3:    rd_mux = {16'd0, sclk_div};
        6'd4:    rd_mux = {22'd0, seq_index};
        6'd5:    rd_mux = {1'b0, poll_count};
        default: rd_mux = 32'd0;
        endcase
    end
    else                              rd_mux = 32'd0;
end

always @(posedge clk) begin
    if (!resetn) begin
        aw_have <= 1'b0; w_have <= 1'b0; bvalid_r <= 1'b0;
        rd_busy <= 1'b0; rd_phase <= 1'b0; rvalid_r <= 1'b0;
        seq_go <= 1'b0;
        poll_en <= 1'b0; chip_reset <= 1'b1; clkbuf_dis <= 1'b1; lvlshift_dis <= 1'b1;
        sclk_div <= SCLK_DIV_RESET;
    end
    else begin
        // Write address/data may arrive in either order
        if (S_AXI_AWVALID && !aw_have) begin aw_have <= 1'b1; aw_addr <= S_AXI_AWADDR; end
        if (S_AXI_WVALID  && !w_have)  begin w_have  <= 1'b1; w_data  <= S_AXI_WDATA;  end
        seq_go <= 1'b0;
        if (do_write) begin
            aw_have  <= 1'b0;
            w_have   <= 1'b0;
            bvalid_r <= 1'b1;
            if (wr_reg) begin
                case (aw_addr[7:2])
                6'd1: begin
                    seq_go       <= w_data[0];
                    poll_en      <= w_data[1];
                    chip_reset   <= w_data[8];
                    clkbuf_dis   <= w_data[9];
                    lvlshift_dis <= w_data[10];
                end
                6'd3: sclk_div <= w_data[15:0];
                default: ;
                endcase
            end
        end
        else if (bvalid_r && S_AXI_BREADY) begin
            bvalid_r <= 1'b0;
        end

        // Reads: memory data is available one cycle after the address
        rd_phase <= 1'b0;
        if (rd_accept) begin
            rd_busy  <= 1'b1;
            rd_addr  <= S_AXI_ARADDR;
            rd_phase <= 1'b1;
        end
        if (rd_phase) begin
            rvalid_r <= 1'b1;
            rdata_r  <= rd_mux;
        end
        if (rvalid_r && S_AXI_RREADY) begin
            rvalid_r <= 1'b0;
            rd_busy  <= 1'b0;
        end
    end
end

//////////////////////////////////////////////////////////////////////////////
// SPI frame engine: one 16-bit frame per spi_start
reg         spi_start = 1'b0;
reg  [15:0] spi_tx    = 16'd0;
reg         spi_done  = 1'b0;
reg  [15:0] spi_rx    = 16'd0;

localparam [2:0] S_IDLE = 3'd0, S_LOW = 3'd1, S_HIGH = 3'd2, S_HOLD = 3'd3, S_GAP = 3'd4;
reg   [2:0] sstate = S_IDLE;
reg  [15:0] sh_tx  = 16'd0;
reg   [3:0] bitn   = 4'd0;
reg  [16:0] hcnt   = 17'd0;
reg         miso_r = 1'b0;

wire [15:0] half   = (sclk_div == 16'd0) ? 16'd1 : sclk_div;
wire [16:0] gap    = ({half, 1'b0} > CS_GAP_MIN) ? {half, 1'b0} : CS_GAP_MIN;

always @(posedge clk) begin
    miso_r   <= spi_miso;
    spi_done <= 1'b0;
    if (!resetn) begin
        sstate   <= S_IDLE;
        spi_csn  <= 1'b1;
        spi_sclk <= 1'b0;
        spi_mosi <= 1'b0;
    end
    else begin
        case (sstate)
        S_IDLE: begin
            spi_csn  <= 1'b1;
            spi_sclk <= 1'b0;
            if (spi_start) begin
                sh_tx    <= spi_tx;
                bitn     <= 4'd15;
                spi_csn  <= 1'b0;
                spi_mosi <= spi_tx[15];
                hcnt     <= half - 1;
                sstate   <= S_LOW;
            end
        end
        S_LOW: begin
            if (hcnt == 0) begin
                spi_sclk <= 1'b1;
                hcnt     <= half - 1;
                sstate   <= S_HIGH;
            end
            else hcnt <= hcnt - 1;
        end
        S_HIGH: begin
            if (hcnt == 0) begin
                spi_rx   <= {spi_rx[14:0], miso_r};
                spi_sclk <= 1'b0;
                hcnt     <= half - 1;
                if (bitn == 0) begin
                    sstate   <= S_HOLD;
                end
                else begin
                    bitn     <= bitn - 1;
                    spi_mosi <= sh_tx[bitn - 1];
                    sstate   <= S_LOW;
                end
            end
            else hcnt <= hcnt - 1;
        end
        S_HOLD: begin
            if (hcnt == 0) begin
                spi_csn  <= 1'b1;
                spi_mosi <= 1'b0;
                hcnt     <= gap - 1;
                sstate   <= S_GAP;
            end
            else hcnt <= hcnt - 1;
        end
        S_GAP: begin
            if (hcnt == 0) begin
                spi_done <= 1'b1;
                sstate   <= S_IDLE;
            end
            else hcnt <= hcnt - 1;
        end
        default: sstate <= S_IDLE;
        endcase
    end
end

//////////////////////////////////////////////////////////////////////////////
// Command engine
localparam [3:0] E_IDLE   = 4'd0, E_FETCH = 4'd1, E_DECODE = 4'd2,
                 E_XFER   = 4'd3, E_XWAIT = 4'd4, E_WB     = 4'd5,
                 E_DELAY  = 4'd6, E_NEXT  = 4'd7, E_FINISH = 4'd8;
reg   [3:0] estate     = E_IDLE;
reg  [31:0] cmd        = 32'd0;
reg         second     = 1'b0;   // 0 = Set Address frame, 1 = data frame
reg  [27:0] delay_cnt  = 28'd0;

wire [31:0] fetched   = ctx_poll ? poll_doutb : seq_doutb;
wire  [3:0] f_op      = fetched[31:28];
wire        at_last   = ctx_poll ? (poll_index == POLL_DEPTH - 1)
                                 : (seq_index  == SEQ_DEPTH  - 1);

always @(posedge clk) begin
    spi_start <= 1'b0;
    eng_we    <= 1'b0;
    if (!resetn) begin
        estate    <= E_IDLE;
        seq_busy  <= 1'b0;
        seq_done  <= 1'b0;
        poll_busy <= 1'b0;
        ctx_poll  <= 1'b0;
        seq_index <= 10'd0;
        poll_index <= 6'd0;
        poll_count <= 31'd0;
    end
    else begin
        if (seq_go && !seq_busy) begin
            seq_busy <= 1'b1;
            seq_done <= 1'b0;
        end
        case (estate)
        E_IDLE: begin
            if (seq_busy) begin
                ctx_poll   <= 1'b0;
                seq_index  <= 10'd0;
                estate     <= E_FETCH;
            end
            else if (poll_en) begin
                ctx_poll   <= 1'b1;
                poll_index <= 6'd0;
                poll_busy  <= 1'b1;
                estate     <= E_FETCH;
            end
        end
        E_FETCH: estate <= E_DECODE;   // RAM output is valid next cycle
        E_DECODE: begin
            cmd <= fetched;
            case (f_op)
            OP_WRITE, OP_READ: begin
                second <= 1'b0;
                estate <= E_XFER;
            end
            OP_DELAY: begin
                delay_cnt <= fetched[27:0];
                estate    <= E_DELAY;
            end
            default: estate <= E_FINISH;   // END and undefined opcodes
            endcase
        end
        E_XFER: begin
            if (!second)                    spi_tx <= {8'h00, cmd[23:16]}; // Set Address
            else if (cmd[31:28] == OP_READ) spi_tx <= 16'h8000;            // Read Data
            else                            spi_tx <= {8'h40, cmd[7:0]};   // Write Data
            spi_start <= 1'b1;
            estate    <= E_XWAIT;
        end
        E_XWAIT: begin
            if (spi_done) begin
                if (second) begin
                    estate <= (cmd[31:28] == OP_READ) ? E_WB : E_NEXT;
                end
                else begin
                    second <= 1'b1;
                    estate <= E_XFER;
                end
            end
        end
        E_WB: begin
            eng_wdata <= {cmd[31:16], spi_rx[7:0], cmd[7:0]};
            eng_we    <= 1'b1;
            estate    <= E_NEXT;
        end
        E_DELAY: begin
            if (delay_cnt == 0) estate <= E_NEXT;
            else                delay_cnt <= delay_cnt - 1;
        end
        E_NEXT: begin
            if (eng_we) begin
                // write-back still in flight (address must stay put)
            end
            else if (at_last) estate <= E_FINISH;
            else begin
                if (ctx_poll) poll_index <= poll_index + 1;
                else          seq_index  <= seq_index + 1;
                estate <= E_FETCH;
            end
        end
        E_FINISH: begin
            if (ctx_poll) begin
                poll_count <= (poll_count == 31'h7FFFFFFF) ? 31'd1 : poll_count + 1;
                poll_busy  <= 1'b0;
            end
            else begin
                seq_busy <= 1'b0;
                seq_done <= 1'b1;
            end
            estate <= E_IDLE;
        end
        default: estate <= E_IDLE;
        endcase
    end
end

endmodule

/*
 * True dual-port block RAM, one clock, read-first. Zero-initialised, so an
 * unloaded memory holds END commands.
 */
module ospreySi539xSeqRAM #(
    parameter AW = 10
    ) (
    input  wire          clk,
    input  wire          wea,
    input  wire [AW-1:0] addra,
    input  wire   [31:0] dina,
    output reg    [31:0] douta,
    input  wire          web,
    input  wire [AW-1:0] addrb,
    input  wire   [31:0] dinb,
    output reg    [31:0] doutb
);
(* ram_style = "block" *) reg [31:0] mem [0:(1<<AW)-1];
integer i;
initial begin
    for (i = 0 ; i < (1<<AW) ; i = i + 1) mem[i] = 32'd0;
    douta = 32'd0;
    doutb = 32'd0;
end
always @(posedge clk) begin
    if (wea) mem[addra] <= dina;
    douta <= mem[addra];
end
always @(posedge clk) begin
    if (web) mem[addrb] <= dinb;
    doutb <= mem[addrb];
end
endmodule
`default_nettype wire
