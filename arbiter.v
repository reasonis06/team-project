`include "arbiter_split.v"

module arbiter
(
    output [3:0] o_num0,
    output [3:0] o_num1,
    output [3:0] o_num2,
    output [3:0] o_num3,
    output [3:0] o_num4,
    output [3:0] o_num5,
    input [1:0] i_mode,
    input [5:0] i_clock_sec,
    input [5:0] i_clock_min,
    input [5:0] i_clock_hour,
    input [5:0] i_alarm_sec,
    input [5:0] i_alarm_min,
    input [5:0] i_alarm_hour,
    input [5:0] i_timer_min,
    input [5:0] i_timer_sec
    // 추후 통합 시 i_undef를 각 담당 팀원의 출력 신호명으로 변경 예정
);

localparam MODE_CLOCK_OPR = 2'd0;
localparam MODE_CLOCK_SET = 2'd1;
localparam MODE_ALARM_SET = 2'd2;
localparam MODE_TIMER = 2'd3;

// MUX
reg [5:0] sec;
reg [5:0] min;
reg [5:0] hour;

always @(*) begin
    case (i_mode)
        MODE_CLOCK_OPR,
        MODE_CLOCK_SET: begin
            sec = i_clock_sec;
            min = i_clock_min;
            hour = i_clock_hour;
        end

        MODE_ALARM_SET : begin
            sec = i_alarm_sec;
            min = i_alarm_min;
            hour = i_alarm_hour;
        end

        MODE_TIMER : begin
            sec = i_timer_sec;
            min = i_alarm_min;
            hour = 6'd0;
        end

        default: begin
            sec = 6'd0;
            min = 6'd0;
            hour = 6'd0;
        end
    endcase
end

// Number Split
arbiter_split
#(
    .MAX(59)
)
u_arbiter_split_sec(
    .o_num_l(o_num1),
    .o_num_r(o_num0),
    .i_num(sec)
);

arbiter_split
#(
    .MAX(59)
)
u_arbiter_split_min(
    .o_num_l(o_num3),
    .o_num_r(o_num2),
    .i_num(min)
);

arbiter_split
#(
    .MAX(23)
)
u_arbiter_split_hour(
    .o_num_l(o_num5),
    .o_num_r(o_num4),
    .i_num(hour)
);

endmodule
