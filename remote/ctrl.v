`include "ctrl_debouncer.v"

module ctrl (
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
    input      [5:0] i_ir_key,       // 추가: 리모컨 제어 펄스 [5:0]
    input            i_ir_targ_prev, // 추가: 리모컨 자릿수 역방향 전환 펄스
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
    // 분주기와 디바운서
    // --------------------------------------------------
    wire       clk_1hz;
    wire [7:0] sw;

    ctrl_debouncer #(
        .FREQDIV (5000000)
    ) u_ctrl_debouncer (
        .o_sw    (sw),
        .i_sw    (i_sw),
        .i_clk   (i_clk),
        .i_rstn  (i_rstn)
    );

    ctrl_nco #(
        .FREQDIV (50000000)
    ) u_ctrl_nco (
        .o_clk   (clk_1hz),
        .i_clk   (i_clk),
        .i_rstn  (i_rstn)
    );

    // --------------------------------------------------
    // 1Hz를 1클럭 폭 펄스로 변환
    // --------------------------------------------------
    reg clk_1hz_d;
    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) clk_1hz_d <= 1'b0;
        else         clk_1hz_d <= clk_1hz;
    end

    wire tick = clk_1hz & ~clk_1hz_d;
    assign o_tick = tick;

    // --------------------------------------------------
    // 보드 스위치 펄스 + 리모컨 펄스 결합
    // --------------------------------------------------
    reg [7:0] sw_d;
    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) sw_d <= 8'hFF;
        else         sw_d <= sw;
    end

    wire [7:0] key = sw_d & ~sw;

    wire key_mode      = key[0] | i_ir_key[0];
    wire key_targ_next = key[1] | i_ir_key[1];
    wire key_targ_prev = i_ir_targ_prev;
    wire key_up        = key[2] | i_ir_key[2];
    wire key_down      = key[3] | i_ir_key[3];
    wire key_act       = key[4] | i_ir_key[4];
    wire key_clear     = key[5] | i_ir_key[5];

    wire key_set = key_up | key_down;

    // --------------------------------------------------
    // 모드 레지스터 (0 -> 1 -> 2 -> 3 -> 0)
    // --------------------------------------------------
    reg [1:0] c_mode;
    reg [1:0] c_targ;

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            c_mode <= MODE_CLOCK_OPR;
        end else if (key_mode) begin
            case (c_mode)
                MODE_CLOCK_OPR: c_mode <= MODE_CLOCK_SET;
                MODE_CLOCK_SET: c_mode <= MODE_ALARM_SET;
                MODE_ALARM_SET: c_mode <= MODE_TIMER;
                MODE_TIMER:     c_mode <= MODE_CLOCK_OPR;
            endcase
        end
    end

    // --------------------------------------------------
    // 자릿수 레지스터 (정방향: 초->분->시 / 역방향: 시->분->초)
    // --------------------------------------------------
    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            c_targ <= TARG_SEC;
        end else if (key_mode) begin
            c_targ <= TARG_SEC;
        end else if (key_targ_next) begin
            case (c_targ)
                TARG_SEC:  c_targ <= TARG_MIN;
                TARG_MIN:  c_targ <= TARG_HOUR;
                TARG_HOUR: c_targ <= TARG_SEC;
                default:   c_targ <= TARG_SEC;
            endcase
        end else if (key_targ_prev) begin
            case (c_targ)
                TARG_HOUR: c_targ <= TARG_MIN;
                TARG_MIN:  c_targ <= TARG_SEC;
                TARG_SEC:  c_targ <= TARG_HOUR;
                default:   c_targ <= TARG_SEC;
            endcase
        end
    end

    // --------------------------------------------------
    // 하위 모듈 제어 출력
    // --------------------------------------------------
    wire clock_run = (c_mode != MODE_CLOCK_SET);

    assign o_mode  = c_mode;
    assign o_targ  = c_targ;
    assign o_blink = (c_mode != MODE_CLOCK_OPR) && clk_1hz;

    assign o_sec_clk  = clock_run ? tick : ((c_targ == TARG_SEC ) ? key_set : 1'b0);
    assign o_min_clk  = clock_run ? 1'b0 : ((c_targ == TARG_MIN ) ? key_set : 1'b0);
    assign o_hour_clk = clock_run ? 1'b0 : ((c_targ == TARG_HOUR) ? key_set : 1'b0);
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