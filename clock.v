`include "clock_cnt.v"

module clock
(
    output [4:0] o_hour,
    output [5:0] o_min,
    output [5:0] o_sec,
    output o_min_max,
    output o_hour_max,
    output o_sec_max,
    input i_hour_clk,
    input i_min_clk,
    input i_sec_clk,
    input i_down,
    input i_rstn
);

clock_cnt
#(
    .MAX(59)
)
u_clock_cnt_sec(
    .o_cnt(o_sec),
    .o_max(o_sec_max),
    .i_clk(i_sec_clk),
    .i_down(i_down),
    .i_rstn(i_rstn)
);

clock_cnt
#(
    .MAX(59)
)
u_clock_cnt_min(
    .o_cnt(o_min),
    .o_max(o_min_max),
    .i_clk(i_min_clk),
    .i_down(i_down),
    .i_rstn(i_rstn)
);

clock_cnt
#(
    .MAX(23)
)
u_clock_cnt_hour(
    .o_cnt(o_hour),
    .o_max(o_hour_max),
    .i_clk(i_hour_clk),
    .i_down(i_down),
    .i_rstn(i_rstn)
);

endmodule
