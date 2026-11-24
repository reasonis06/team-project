// ==================================================
//  * Filename      : ctrl.v
//  * Description   : 버튼 입력과 모드 관리
//
//  원본 포트는 하나도 지우거나 이름을 바꾸지 않았음. 아래 3개만 추가했음
//    o_timer_set_hour : 타이머 시 변경 (timer.v가 시·분·초가 되면서 필요)
//    o_timer_clear    : 타이머 초기화 (sw5)
//    o_tick           : 1Hz 1클럭 펄스. 모드와 무관하게 항상 나감
//
//  달라진 점은 신호의 "폭"임
//    원본 : o_sec_clk 등이 50% 듀티 클럭이었고 카운터의 클럭 입력으로 쓰임
//    수정 : o_sec_clk 등이 1클럭 폭 enable 펄스. 카운터는 i_clk로 돌고
//           이 신호는 enable로만 쓰임
//    모드가 바뀌는 순간 가짜 상승엣지가 생기던 문제가 사라짐
//
//  i_hour_max / i_min_max / i_sec_max 는 더 이상 쓰지 않음
//  자리올림을 clock.v가 자기 값을 보고 직접 만들기 때문임. 포트는 호환을 위해 남겨둠
// ==================================================
`include "ctrl_debouncer.v"

module ctrl
(
    output     [1:0] o_mode,
    output           o_hour_clk,
    output           o_min_clk,
    output           o_sec_clk,
    output           o_down,
    output     [1:0] o_targ,
    output           o_blink,

    output           o_alarm_hour_clk,
    output           o_alarm_min_clk,
    output           o_alarm_sec_clk,
    output           o_alarm_down,
    output           o_alarm_en_clk,

    output           o_timer_set_en,
    output           o_timer_set_hour,
    output           o_timer_set_min,
    output           o_timer_set_sec,
    output           o_timer_set_dec,
    output           o_timer_start,
    output           o_timer_clear,

    output           o_tick,

    input            i_hour_max,
    input            i_min_max,
    input            i_sec_max,
    input      [7:0] i_sw,
    input            i_clk,
    input            i_rstn
);

localparam MODE_CLOCK_OPR = 2'd0;
localparam MODE_CLOCK_SET = 2'd1;
localparam MODE_ALARM_SET = 2'd2;
localparam MODE_TIMER     = 2'd3;
localparam TARG_SEC  = 2'd0;
localparam TARG_MIN  = 2'd1;
localparam TARG_HOUR = 2'd2;

// --------------------------------------------------
//  분주기와 디바운서
// --------------------------------------------------
wire clk_1hz;
wire [7:0] sw;

ctrl_debouncer
#(
    .FREQDIV(5000000)
)
u_ctrl_debouncer(
    .o_sw(sw),
    .i_sw(i_sw),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

ctrl_nco
#(
    .FREQDIV(50000000)
)
u_ctrl_nco(
    .o_clk(clk_1hz),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

// --------------------------------------------------
//  1Hz를 1클럭 폭 펄스로
// --------------------------------------------------
reg clk_1hz_d;

always @(posedge i_clk or negedge i_rstn) begin
    if(!i_rstn)     clk_1hz_d <= 1'b0;
    else            clk_1hz_d <= clk_1hz;
end

wire tick = clk_1hz & ~clk_1hz_d;

assign o_tick = tick;

// --------------------------------------------------
//  버튼을 1클럭 폭 펄스로
//  디바운서 출력 sw는 누른 순간 한 샘플 동안만 0이 됨
// --------------------------------------------------
reg [7:0] sw_d;

always @(posedge i_clk or negedge i_rstn) begin
    if(!i_rstn)     sw_d <= 8'hFF;
    else            sw_d <= sw;
end

wire [7:0] key = sw_d & ~sw;        // 하강엣지 = 눌린 순간

wire key_mode  = key[0];
wire key_targ  = key[1];
wire key_up    = key[2];
wire key_down  = key[3];
wire key_act   = key[4];
wire key_clear = key[5];

wire key_set   = key_up | key_down;

// --------------------------------------------------
//  모드 / 자리 레지스터
// --------------------------------------------------
reg [1:0] c_mode;
reg [1:0] c_targ;

always @(posedge i_clk or negedge i_rstn) begin
    if(!i_rstn) begin
        c_mode <= MODE_CLOCK_OPR;
    end else if(key_mode) begin
        case(c_mode)
            MODE_CLOCK_OPR: c_mode <= MODE_CLOCK_SET;
            MODE_CLOCK_SET: c_mode <= MODE_ALARM_SET;
            MODE_ALARM_SET: c_mode <= MODE_TIMER;
            MODE_TIMER:     c_mode <= MODE_CLOCK_OPR;
        endcase
    end
end

// 타이머도 시·분·초를 다 쓰므로 모든 모드에서 자리 순환이 같음
always @(posedge i_clk or negedge i_rstn) begin
    if(!i_rstn) begin
        c_targ <= TARG_SEC;
    end else if(key_mode) begin
        c_targ <= TARG_SEC;             // 모드를 바꾸면 자리는 초부터
    end else if(key_targ) begin
        case(c_targ)
            TARG_SEC:   c_targ <= TARG_MIN;
            TARG_MIN:   c_targ <= TARG_HOUR;
            TARG_HOUR:  c_targ <= TARG_SEC;
            default:    c_targ <= TARG_SEC;
        endcase
    end
end

// --------------------------------------------------
//  출력
//  일반 / 알람설정 / 타이머 모드에서는 tick으로 초가 감
//  시계설정 모드에서는 선택한 자리만 설정 버튼 펄스로 바뀜
//  분·시 자리올림은 clock.v가 자기 값을 보고 직접 만듦
// --------------------------------------------------
wire clock_run = (c_mode != MODE_CLOCK_SET);

assign o_mode  = c_mode;
assign o_targ  = c_targ;
assign o_blink = (c_mode != MODE_CLOCK_OPR) && clk_1hz;

assign o_sec_clk  = clock_run ? tick
                              : ((c_targ == TARG_SEC ) ? key_set : 1'b0);
assign o_min_clk  = clock_run ? 1'b0
                              : ((c_targ == TARG_MIN ) ? key_set : 1'b0);
assign o_hour_clk = clock_run ? 1'b0
                              : ((c_targ == TARG_HOUR) ? key_set : 1'b0);
assign o_down     = clock_run ? 1'b0 : key_down;

assign o_alarm_sec_clk  = (c_mode == MODE_ALARM_SET) && (c_targ == TARG_SEC ) && key_set;
assign o_alarm_min_clk  = (c_mode == MODE_ALARM_SET) && (c_targ == TARG_MIN ) && key_set;
assign o_alarm_hour_clk = (c_mode == MODE_ALARM_SET) && (c_targ == TARG_HOUR) && key_set;
assign o_alarm_down     = (c_mode == MODE_ALARM_SET) && key_down;
assign o_alarm_en_clk   = (c_mode == MODE_ALARM_SET) && key_act;

assign o_timer_set_en   = (c_mode == MODE_TIMER);
assign o_timer_set_sec  = (c_mode == MODE_TIMER) && (c_targ == TARG_SEC ) && key_set;
assign o_timer_set_min  = (c_mode == MODE_TIMER) && (c_targ == TARG_MIN ) && key_set;
assign o_timer_set_hour = (c_mode == MODE_TIMER) && (c_targ == TARG_HOUR) && key_set;
assign o_timer_set_dec  = (c_mode == MODE_TIMER) && key_down;
assign o_timer_start    = (c_mode == MODE_TIMER) && key_act;
assign o_timer_clear    = (c_mode == MODE_TIMER) && key_clear;

endmodule
