`include "arbiter.v"
`include "clock.v"
`include "ctrl.v"
`include "ssegdisp.v"

module top
(
    output [5:0] o_seg_enb,
    output [7:0] o_seg,
    input [7:0] i_sw,
    input i_clk,
    input i_rstn
);

wire mode;
wire hour_clk;
wire min_clk;
wire sec_clk;
wire down;
wire [1:0] targ;
wire blink;
wire hour_max;
wire min_max;
wire sec_max;
wire [4:0] clock_hour;
wire [5:0] clock_min;
wire [5:0] clock_sec;
wire [3:0] disp_num[0:5];

ctrl
u_ctrl(
    .o_mode(mode),
    .o_hour_clk(hour_clk),
    .o_min_clk(min_clk),
    .o_sec_clk(sec_clk),
    .o_down(down),
    .o_targ(targ),
    .o_blink(blink),
    .i_hour_max(hour_max),
    .i_min_max(min_max),
    .i_sec_max(sec_max),
    .i_sw(i_sw),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

clock
u_clock(
    .o_hour(clock_hour),
    .o_min(clock_min),
    .o_sec(clock_sec),
    .o_hour_max(hour_max),
    .o_min_max(min_max),
    .o_sec_max(sec_max),
    .i_hour_clk(hour_clk),
    .i_min_clk(min_clk),
    .i_sec_clk(sec_clk),
    .i_down(down),
    .i_rstn(i_rstn)
);

arbiter
u_arbiter(
    .o_num0(disp_num[0]),
    .o_num1(disp_num[1]),
    .o_num2(disp_num[2]),
    .o_num3(disp_num[3]),
    .o_num4(disp_num[4]),
    .o_num5(disp_num[5]),
    .i_mode(mode),
    .i_clock_sec(clock_sec),
    .i_clock_min(clock_min),
    .i_clock_hour(clock_hour),
    .i_undef_sec(6'd99),
    .i_undef_min(6'd99),
    .i_undef_hour(6'd23)
);

ssegdisp
#(
    .FREQDIV(5000)
)
u_ssegdisp(
    .o_seg_enb(o_seg_enb),
    .o_seg(o_seg),
    .i_num0(disp_num[0]),
    .i_num1(disp_num[1]),
    .i_num2(disp_num[2]),
    .i_num3(disp_num[3]),
    .i_num4(disp_num[4]),
    .i_num5(disp_num[5]),
    .i_dp0(1'b0),
    .i_dp1(1'b0),
    .i_dp2(1'b1),
    .i_dp3(1'b0),
    .i_dp4(1'b0),
    .i_dp5(1'b0),
    .i_blink(blink),
    .i_targ(targ),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

endmodule
