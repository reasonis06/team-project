`include "buzzer.v"

module alarm_tb
(
    output       o_buzzer,
    output [5:0] o_seg_enb,
    output [7:0] o_seg,
    input  [7:0] i_sw,
    input        i_clk,
    input        i_rstn
);

// 테스트 중 7세그먼트 디스플레이 불필요한 점등 방지 (전체 OFF)
assign o_seg_enb = 6'b111111;
assign o_seg     = 8'b00000000;

// 버저 모듈 직접 연결 (i_enb를 1'b0으로 고정하여 항상 알람 활성화 상태 유지)
buzzer u_buzzer(
    .o_out  (o_buzzer ),
    .i_enb  (1'b0     ), // 0일 때 버저 ON[cite: 8, 11]
    .i_clk  (i_clk    ),
    .i_rstn (i_rstn   )
);

endmodule