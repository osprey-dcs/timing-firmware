/* SPDX-License-Identifier: BSD-3-Clause
 * Copyright Osprey DCS 2026
 */
`default_nettype none
`timescale  1 ns / 1 ns

// counter which will be sampled from a different clock domain
module asyncounter #(
    parameter N = 32
)(
    input wire tick_clk,
    input wire tick,
    input wire latch,
    input wire reset,

    input wire samp_clk,
    output wire [N-1:0] count
);

reg [N-1:0] count_t = 0;
reg [N-1:0] count_t_g = 0;

always @(posedge tick_clk) begin
    if(reset)
        count_t <= 0;
    else if(tick)
        count_t <= count_t + 1;

    if(latch)
        count_t_g <= count_t ^ {1'b0, count_t[N-1:1]}; // binary to gray code
end

(*ASYNC_REG="true"*)
reg [N-1:0] count_s_g [0:1];
always @(posedge samp_clk) begin
    count_s_g[0] <= count_t_g;
    count_s_g[1] <= count_s_g[0];
end

gray2bin #(.N(N)) G2B_samp(
    .G(count_s_g[1]),
    .B(count)
);

endmodule

// variable width gray code to binary
module gray2bin #(
    parameter N = 32
)(
    input wire [N-1:0] G,
    output wire [N-1:0] B
);

assign B[N-1] = G[N-1];

genvar i;
generate
for(i=0; i < N-1; i = i + 1) begin : grayBit
    assign B[i] = G[i] ^ B[i+1];
end
endgenerate

endmodule
