// ==================================================
//  * Filename      : clock.v
//  * Description   : 시 / 분 / 초 시계
//
//  포트는 원본과 같음. i_clk 하나만 추가했음
//  i_hour_clk / i_min_clk / i_sec_clk 은 1클럭 폭 enable 펄스임
//
//  자리올림 / 자리내림을 이 모듈 안에서 처리함
//    초가 59일 때 올리면 분이 +1, 초가 0일 때 내리면 분이 -1
//    분이 59일 때 올리면 시가 +1, 분이 0일 때 내리면 시가 -1
//  일반 동작과 설정 모드 모두 같은 규칙으로 동작함
//  ctrl은 "어느 자리를 건드릴지"만 알려주면 되고 자리올림은 신경쓰지 않음
// ==================================================
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
    input i_clk,
    input i_rstn
);

// 자리올림 / 자리내림
wire sec_carry;
wire min_en;
wire min_carry;
wire hour_en;

assign sec_carry = i_sec_clk && (i_down ? (o_sec == 6'd0) : (o_sec == 6'd59));
assign min_en    = i_min_clk | sec_carry;
assign min_carry = min_en    && (i_down ? (o_min == 6'd0) : (o_min == 6'd59));
assign hour_en   = i_hour_clk | min_carry;

clock_cnt
#(
    .MAX(59)
)
u_clock_cnt_sec(
    .o_cnt(o_sec),
    .o_max(o_sec_max),
    .i_en(i_sec_clk),
    .i_clk(i_clk),
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
    .i_en(min_en),
    .i_clk(i_clk),
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
    .i_en(hour_en),
    .i_clk(i_clk),
    .i_down(i_down),
    .i_rstn(i_rstn)
);

endmodule
