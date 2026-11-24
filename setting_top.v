`include "arbiter.v"
`include "clock.v"
`include "ctrl.v"
`include "ssegdisp.v"
`include "alarm.v"
`include "timer.v"

module setting_top
(
    output [1:0] o_mode,
    output [5:0] o_seg_enb,
    output [7:0] o_seg,
    input [7:0] i_sw,
    input i_clk,
    input i_rstn
);

wire [1:0] mode;
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


wire alarm_hour_clk;
wire alarm_min_clk;
wire alarm_sec_clk;
wire alarm_down;
wire alarm_en_clk;

wire [4:0] alarm_hour;
wire [5:0] alarm_min;
wire [5:0] alarm_sec;
wire alarm_en;
wire alarm_ring;

wire timer_set_en;
wire timer_set_min;
wire timer_set_sec;
wire timer_set_dec;
wire timer_start;

wire [5:0] timer_min;
wire [5:0] timer_sec;
wire timer_run;
wire timer_expire;
wire timer_expire_start;



assign o_mode = mode;

ctrl
u_ctrl(
    .o_mode(mode),
    .o_hour_clk(hour_clk),
    .o_min_clk(min_clk),
    .o_sec_clk(sec_clk),
    .o_down(down),
    .o_targ(targ),
    .o_blink(blink),
    .o_alarm_hour_clk(alarm_hour_clk),
    .o_alarm_min_clk(alarm_min_clk),
    .o_alarm_sec_clk(alarm_sec_clk),
    .o_alarm_down(alarm_down),
    .o_alarm_en_clk(alarm_en_clk),
    .o_timer_set_en(timer_set_en),
    .o_timer_set_min(timer_set_min),
    .o_timer_set_sec(timer_set_sec),
    .o_timer_set_dec(timer_set_dec),
    .o_timer_start(timer_start),
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


alarm
u_alarm(
    .o_alarm_hour(alarm_hour),
    .o_alarm_min(alarm_min),
    .o_alarm_sec(alarm_sec),
    .o_alarm_en(alarm_en),
    .o_alarm_ring(alarm_ring),
    .i_clock_hour(clock_hour),
    .i_clock_min(clock_min),
    .i_clock_sec(clock_sec),
    .i_hour_clk(alarm_hour_clk),
    .i_min_clk(alarm_min_clk),
    .i_sec_clk(alarm_sec_clk),
    .i_en_clk(alarm_en_clk),
    .i_rstn(i_rstn)
);

timer
u_timer(
    .o_min(timer_min),
    .o_sec(timer_sec),
    .o_run(timer_run),
    .o_expire(timer_expire),
    .o_expire_start(timer_expire_start),
    .i_set_en(timer_set_en),
    .i_set_min(timer_set_min),
    .i_set_sec(timer_set_sec),
    .i_set_dec(timer_set_dec),
    .i_tick(sec_clk),
    .i_start(timer_start),
    .i_clear(1'b0),
    .i_clk(i_clk),
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
    .i_alarm_sec(alarm_sec),
    .i_alarm_min(alarm_min),
    .i_alarm_hour({1'b0, alarm_hour}),
    .i_timer_min(timer_min),
    .i_timer_sec(timer_sec)
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
