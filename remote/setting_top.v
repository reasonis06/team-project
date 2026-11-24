`include "arbiter.v"
`include "clock.v"
`include "ctrl.v"
`include "ssegdisp.v"
`include "alarm.v"
`include "timer.v"
`include "buzzer.v"
`include "lcd/lcd_top.v"
`include "ir.v"

module setting_top (
    output [5:0] o_seg_enb,
    output [7:0] o_seg,
    output       o_buzzer,
    output       o_lcd_e,
    output       o_lcd_rs,
    output       o_lcd_rw,
    inout  [7:0] io_lcd_data,
    input  [7:0] i_sw,
    input        i_ir_rxb,      // 추가: IR 리모컨 수신 핀
    input        i_clk,
    input        i_rstn
);

    wire [1:0] mode;
    wire [1:0] targ;
    wire       blink;
    wire       tick;

    wire       hour_clk;
    wire       min_clk;
    wire       sec_clk;
    wire       down;
    wire       hour_max;
    wire       min_max;
    wire       sec_max;

    wire [4:0] clock_hour;
    wire [5:0] clock_min;
    wire [5:0] clock_sec;
    wire [3:0] disp_num[0:5];

    wire       alarm_hour_clk;
    wire       alarm_min_clk;
    wire       alarm_sec_clk;
    wire       alarm_down;
    wire       alarm_en_clk;
    wire [4:0] alarm_hour;
    wire [5:0] alarm_min;
    wire [5:0] alarm_sec;
    wire       alarm_en;
    wire       alarm_ring;

    wire       timer_set_en;
    wire       timer_set_hour;
    wire       timer_set_min;
    wire       timer_set_sec;
    wire       timer_set_dec;
    wire       timer_start;
    wire       timer_clear;
    wire [4:0] timer_hour;
    wire [5:0] timer_min;
    wire [5:0] timer_sec;
    wire       timer_run;
    wire       timer_expire;
    wire       timer_expire_start;

    wire       buzzer_enb;

    // --------------------------------------------------
    // IR 리모컨 수신 및 시스템 리셋 결합
    // --------------------------------------------------
    wire [31:0] ir_data;
    wire        ir_rst;
    wire [5:0]  ir_key;
    wire        ir_targ_prev;
    wire        sys_rstn = i_rstn & ~ir_rst; // 하드웨어 리셋 또는 리모컨 되돌리기(0xFD609F)

    ir u_ir (
        .o_data         (ir_data),
        .o_ir_rst       (ir_rst),
        .o_ir_key       (ir_key),
        .o_ir_targ_prev (ir_targ_prev),
        .i_ir_rxb       (i_ir_rxb),
        .i_clk          (i_clk),
        .i_rstn         (i_rstn)
    );

    // --------------------------------------------------
    // 제어 및 기능 모듈 연결 (sys_rstn 사용)
    // --------------------------------------------------
    ctrl u_ctrl (
        .o_mode           (mode),
        .o_hour_clk       (hour_clk),
        .o_min_clk        (min_clk),
        .o_sec_clk        (sec_clk),
        .o_down           (down),
        .o_targ           (targ),
        .o_blink          (blink),
        .o_alarm_hour_clk (alarm_hour_clk),
        .o_alarm_min_clk  (alarm_min_clk),
        .o_alarm_sec_clk  (alarm_sec_clk),
        .o_alarm_down     (alarm_down),
        .o_alarm_en_clk   (alarm_en_clk),
        .o_timer_set_en   (timer_set_en),
        .o_timer_set_hour (timer_set_hour),
        .o_timer_set_min  (timer_set_min),
        .o_timer_set_sec  (timer_set_sec),
        .o_timer_set_dec  (timer_set_dec),
        .o_timer_start    (timer_start),
        .o_timer_clear    (timer_clear),
        .o_tick           (tick),
        .i_hour_max       (hour_max),
        .i_min_max        (min_max),
        .i_sec_max        (sec_max),
        .i_sw             (i_sw),
        .i_ir_key         (ir_key),
        .i_ir_targ_prev   (ir_targ_prev),
        .i_clk            (i_clk),
        .i_rstn           (sys_rstn)
    );

    clock u_clock (
        .o_hour     (clock_hour),
        .o_min      (clock_min),
        .o_sec      (clock_sec),
        .o_hour_max (hour_max),
        .o_min_max  (min_max),
        .o_sec_max  (sec_max),
        .i_hour_clk (hour_clk),
        .i_min_clk  (min_clk),
        .i_sec_clk  (sec_clk),
        .i_down     (down),
        .i_clk      (i_clk),
        .i_rstn     (sys_rstn)
    );

    alarm #(
        .RING_SEC (5)
    ) u_alarm (
        .o_alarm_hour (alarm_hour),
        .o_alarm_min  (alarm_min),
        .o_alarm_sec  (alarm_sec),
        .o_alarm_en   (alarm_en),
        .o_alarm_ring (alarm_ring),
        .i_clock_hour (clock_hour),
        .i_clock_min  (clock_min),
        .i_clock_sec  (clock_sec),
        .i_hour_clk   (alarm_hour_clk),
        .i_min_clk    (alarm_min_clk),
        .i_sec_clk    (alarm_sec_clk),
        .i_en_clk     (alarm_en_clk),
        .i_down       (alarm_down),
        .i_tick       (tick),
        .i_clk        (i_clk),
        .i_rstn       (sys_rstn)
    );

    timer #(
        .EXPIRE_SEC (5)
    ) u_timer (
        .o_hour         (timer_hour),
        .o_min          (timer_min),
        .o_sec          (timer_sec),
        .o_run          (timer_run),
        .o_expire       (timer_expire),
        .o_expire_start (timer_expire_start),
        .i_set_en       (timer_set_en),
        .i_set_hour     (timer_set_hour),
        .i_set_min      (timer_set_min),
        .i_set_sec      (timer_set_sec),
        .i_set_dec      (timer_set_dec),
        .i_tick         (tick),
        .i_start        (timer_start),
        .i_clear        (timer_clear),
        .i_clk          (i_clk),
        .i_rstn         (sys_rstn)
    );

    arbiter u_arbiter (
        .o_num0       (disp_num[0]),
        .o_num1       (disp_num[1]),
        .o_num2       (disp_num[2]),
        .o_num3       (disp_num[3]),
        .o_num4       (disp_num[4]),
        .o_num5       (disp_num[5]),
        .i_mode       (mode),
        .i_clock_sec  (clock_sec),
        .i_clock_min  (clock_min),
        .i_clock_hour ({1'b0, clock_hour}),
        .i_alarm_sec  (alarm_sec),
        .i_alarm_min  (alarm_min),
        .i_alarm_hour ({1'b0, alarm_hour}),
        .i_timer_hour ({1'b0, timer_hour}),
        .i_timer_min  (timer_min),
        .i_timer_sec  (timer_sec)
    );

    ssegdisp #(
        .FREQDIV (5000)
    ) u_ssegdisp (
        .o_seg_enb (o_seg_enb),
        .o_seg     (o_seg),
        .i_num0    (disp_num[0]),
        .i_num1    (disp_num[1]),
        .i_num2    (disp_num[2]),
        .i_num3    (disp_num[3]),
        .i_num4    (disp_num[4]),
        .i_num5    (disp_num[5]),
        .i_dp0     (1'b0),
        .i_dp1     (1'b0),
        .i_dp2     (1'b1),
        .i_dp3     (1'b0),
        .i_dp4     (1'b0),
        .i_dp5     (alarm_en),
        .i_blink   (blink),
        .i_targ    (targ),
        .i_clk     (i_clk),
        .i_rstn    (sys_rstn)
    );

    assign buzzer_enb = ~(alarm_ring | timer_expire);

    buzzer u_buzzer (
        .o_out  (o_buzzer),
        .i_enb  (buzzer_enb),
        .i_clk  (i_clk),
        .i_rstn (sys_rstn)
    );

    lcd_top #(
        .TEXT_FREQDIV (5000000)
    ) u_lcd_top (
        .o_lcd_e      (o_lcd_e),
        .o_lcd_rs     (o_lcd_rs),
        .o_lcd_rw     (o_lcd_rw),
        .io_lcd_data  (io_lcd_data),
        .i_mode       (mode),
        .i_alarm_hour (alarm_hour),
        .i_alarm_min  (alarm_min),
        .i_alarm_en   (alarm_en),
        .i_clk        (i_clk),
        .i_rstn       (sys_rstn)
    );

endmodule