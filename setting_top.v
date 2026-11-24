// ==================================================
//  * Filename      : setting_top.v
//  * Description   : 팀 프로젝트 통합 Top
//                    ctrl + clock + alarm + timer + arbiter + ssegdisp
//                    + buzzer + lcd_top
//
//  원본(feat/setting) 대비 달라진 점
//    - buzzer 인스턴스와 o_buzzer 포트 추가
//      (핀을 안 주면 약한 풀업 때문에 보드에서 버저가 계속 울림)
//    - lcd_top 인스턴스와 LCD 포트 추가
//    - 각 모듈에 i_clk 연결 (전부 동기 설계로 바뀜)
//    - timer가 시·분·초가 되면서 o_hour, i_set_hour 연결 추가
//    - timer의 i_tick을 sec_clk이 아니라 ctrl의 o_tick에 연결
//      (모드에 따라 타이머가 멈추거나 튀던 문제 해결)
//    - timer의 i_clear를 sw5에 연결
//    - o_mode 출력 포트 삭제 (어디에도 안 쓰이는데 핀만 차지했음)
//    - 왼쪽 끝 자리 소수점으로 알람 ON/OFF 표시
//
//  버튼
//    i_rstn  J15  리셋
//    i_sw[0] C9   모드 전환   일반 -> 시계설정 -> 알람설정 -> 타이머 -> 일반
//    i_sw[1] D9   자리 전환   초 -> 분 -> 시 -> 초
//    i_sw[2] E11  값 증가
//    i_sw[3] E10  값 감소
//    i_sw[4] C11  알람설정: 알람 ON/OFF   타이머: 시작 / 일시정지
//    i_sw[5] B11  타이머: 00:00:00 으로 초기화
//    PSD 센서   버저가 울리는 중에 손을 가까이 대면 알람·타이머 정지
//
//  표시
//    7세그 : 시시 분분.초초
//    오른쪽 끝 자리 소수점이 켜져 있으면 PSD가 손을 감지한 상태
//    왼쪽 끝 자리 소수점이 켜져 있으면 알람 ON
//    설정 모드에서는 선택한 자리가 1초 주기로 깜빡임
//    LCD   : 1행 현재 모드, 2행 알람 시각과 ON/OFF
// ==================================================
`include "arbiter.v"
`include "clock.v"
`include "ctrl.v"
`include "ssegdisp.v"
`include "alarm.v"
`include "timer.v"
`include "buzzer.v"
`include "psd.v"
`include "psd_stop.v"
`include "lcd/lcd_top.v"

module setting_top
(
    output [5:0] o_seg_enb,
    output [7:0] o_seg,
    output       o_buzzer,
    output       o_sclk,
    output       o_csn,
    output       o_din,
    input        i_dout,
    output       o_lcd_e,
    output       o_lcd_rs,
    output       o_lcd_rw,
    inout  [7:0] io_lcd_data,
    input [7:0] i_sw,
    input i_clk,
    input i_rstn
);

wire [1:0] mode;
wire [1:0] targ;
wire blink;
wire tick;

wire hour_clk;
wire min_clk;
wire sec_clk;
wire down;
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

wire buzzer_enb;

wire [11:0] psd_data;
wire        psd_near;
wire        psd_detect;
wire        psd_stop_pulse;

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
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

alarm
#(
    .RING_SEC(5)
)
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
    .i_down(alarm_down),
    .i_tick(tick),
    .i_stop(psd_stop_pulse),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

timer
#(
    .EXPIRE_SEC(5)
)
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
    .i_clear(timer_clear | (psd_stop_pulse & timer_expire)),
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
    .i_dp0(psd_near),           // 손 감지 중이면 오른쪽 끝 자리에 점
    .i_dp1(1'b0),
    .i_dp2(1'b1),
    .i_dp3(1'b0),
    .i_dp4(1'b0),
    .i_dp5(alarm_en),           // 알람 ON이면 왼쪽 끝 자리에 점
    .i_blink(blink),
    .i_targ(targ),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

// --------------------------------------------------
//  PSD 센서
//  버저가 울리는 중에만 정지 펄스를 냄.
//  그냥 지나가다 손이 닿아도 시계나 동작 중인 타이머는 건드리지 않음
// --------------------------------------------------
psd
u_psd(
    .o_sclk(o_sclk),
    .o_csn(o_csn),
    .o_din(o_din),
    .o_data(psd_data),
    .i_dout(i_dout),
    .i_addr(3'd0),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

psd_stop
u_psd_stop(
    .o_near(psd_near),
    .o_detect(psd_detect),
    .i_data(psd_data),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

assign psd_stop_pulse = psd_detect & (alarm_ring | timer_expire);

// i_enb 1 = 소리 꺼짐
assign buzzer_enb = ~(alarm_ring | timer_expire);

buzzer
u_buzzer(
    .o_out(o_buzzer),
    .i_enb(buzzer_enb),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

lcd_top
#(
    .TEXT_FREQDIV(5000000)      // 50MHz -> 10Hz, 화면 갱신 0.1초
)
u_lcd_top(
    .o_lcd_e(o_lcd_e),
    .o_lcd_rs(o_lcd_rs),
    .o_lcd_rw(o_lcd_rw),
    .io_lcd_data(io_lcd_data),
    .i_mode(mode),
    .i_alarm_hour(alarm_hour),
    .i_alarm_min(alarm_min),
    .i_alarm_sec(alarm_sec),
    .i_alarm_en(alarm_en),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

endmodule
