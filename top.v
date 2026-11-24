`include "arbiter.v"
`include "clock.v"
`include "ctrl.v"
`include "ssegdisp.v"
`include "alarm.v"
`include "timer.v"
`include "buzzer.v"
`include "lcd_top.v"
`include "psd.v"
`include "psd_detect.v"
`include "ir.v"
`include "ir_key.v"

module top
#(
    parameter PSD_CH = 3'd0,
    parameter PSD_TH_ON = 12'd1800,
    parameter PSD_TH_OFF = 12'd1300,
    parameter IR_FREQDIV = 50,
    parameter IR_HOLD = 10000000
)
(
    output [1:0] o_mode,
    output [5:0] o_seg_enb,
    output [7:0] o_seg,
    output o_lcd_e,
    output o_lcd_rs,
    output o_lcd_rw,
    inout [7:0] io_lcd_data,
    output o_buzz,
    output o_adc_sclk,
    output o_adc_csn,
    output o_adc_din,
    input i_adc_dout,
    input i_ir_rxb,
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
wire tick;
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
wire timer_set_hour;
wire timer_set_min;
wire timer_set_sec;
wire timer_set_dec;
wire timer_start;
wire timer_clear;

wire [4:0] timer_hour;
wire [5:0] timer_min;
wire [5:0] timer_sec;
wire timer_run;
wire timer_expire;
wire timer_expire_start;

wire [11:0] psd_data;
wire psd_near;
wire psd_pulse;

wire [31:0] ir_data;
wire ir_valid;
wire [7:0] ir_sw;
wire [7:0] sw;

assign o_mode = mode;
assign sw = i_sw & ir_sw;

ir
#(
    .FREQDIV(IR_FREQDIV)
)
u_ir(
    .o_data(ir_data),
    .o_valid(ir_valid),
    .i_ir_rxb(i_ir_rxb),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

ir_key
#(
    .HOLD(IR_HOLD)
)
u_ir_key(
    .o_sw(ir_sw),
    .o_cmd(),
    .i_data(ir_data),
    .i_valid(ir_valid),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

psd
u_psd(
    .o_sclk(o_adc_sclk),
    .o_csn(o_adc_csn),
    .o_din(o_adc_din),
    .o_data(psd_data),
    .i_dout(i_adc_dout),
    .i_addr(PSD_CH),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

psd_detect
#(
    .TH_ON(PSD_TH_ON),
    .TH_OFF(PSD_TH_OFF)
)
u_psd_detect(
    .o_near(psd_near),
    .i_data(psd_data),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

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
    .o_timer_set_hour(timer_set_hour),
    .o_timer_set_min(timer_set_min),
    .o_timer_set_sec(timer_set_sec),
    .o_timer_set_dec(timer_set_dec),
    .o_timer_start(timer_start),
    .o_timer_clear(timer_clear),
    .o_tick(tick),
    .i_hour_max(hour_max),
    .i_min_max(min_max),
    .i_sec_max(sec_max),
    .i_sw(sw),
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
    .i_carry_en(mode != 2'd1),
    .i_clk(i_clk),
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
    .i_down(alarm_down),
    .i_en_clk(alarm_en_clk),
    .i_tick(tick),
    .i_stop(psd_pulse),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

timer
u_timer(
    .o_hour(timer_hour),
    .o_min(timer_min),
    .o_sec(timer_sec),
    .o_run(timer_run),
    .o_expire(timer_expire),
    .o_expire_start(timer_expire_start),
    .i_set_en(timer_set_en),
    .i_set_hour(timer_set_hour),
    .i_set_min(timer_set_min),
    .i_set_sec(timer_set_sec),
    .i_set_dec(timer_set_dec),
    .i_tick(tick),
    .i_start(timer_start),
    .i_clear(timer_clear),
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
    .i_clock_hour({1'b0, clock_hour}),
    .i_alarm_sec(alarm_sec),
    .i_alarm_min(alarm_min),
    .i_alarm_hour({1'b0, alarm_hour}),
    .i_timer_hour({1'b0, timer_hour}),
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
    .i_dp5(alarm_en),
    .i_blink(blink),
    .i_targ(targ),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

buzzer
u_buzzer(
    .o_out(o_buzz),
    .i_enb(~(alarm_ring | timer_expire)),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

lcd_top
u_lcd_top(
    .o_lcd_e(o_lcd_e),
    .o_lcd_rs(o_lcd_rs),
    .o_lcd_rw(o_lcd_rw),
    .io_lcd_data(io_lcd_data),
    .o_page(),
    .o_psd_pulse(psd_pulse),
    .i_mode(mode),
    .i_psd(psd_near),
    .i_clock_hour(clock_hour),
    .i_clock_min(clock_min),
    .i_clock_sec(clock_sec),
    .i_alarm_hour(alarm_hour),
    .i_alarm_min(alarm_min),
    .i_alarm_sec(alarm_sec),
    .i_alarm_en(alarm_en),
    .i_timer_hour(timer_hour),
    .i_timer_min(timer_min),
    .i_timer_sec(timer_sec),
    .i_timer_run(timer_run),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

endmodule
