`include "alarm_cnt.v"

module alarm
(
    // 1. LCD 및 Top으로 전달할 출력
    output     [4:0] o_alarm_hour, // 알람 시 (0~23)
    output     [5:0] o_alarm_min,  // 알람 분 (0~59)
    output     [5:0] o_alarm_sec,  // 알람 초 (0~59)
    output reg       o_alarm_en,   // 알람 켜짐(1), 꺼짐(0)
    output           o_alarm_ring, // 1: 알람 울림 조건 충족

    // 2. 현재 시각 입력
    input      [4:0] i_clock_hour, // 현재 시 (0~23)
    input      [5:0] i_clock_min,  // 현재 분 (0~59)
    input      [5:0] i_clock_sec,  // 현재 분 (0~59)

    // 3. 알람 설정 입력
    input            i_hour_clk,   // 알람 시(Hour) 증가 클럭
    input            i_min_clk,    // 알람 분(Min) 증가 클럭
    input            i_sec_clk,    // 알람 초(Sec) 증가 클럭
    input            i_en_clk,     // 알람 ON/OFF 토글 클럭
    input            i_rstn
);

    // 알람 시 (0 ~ 23) 카운터
    alarm_cnt
    #(
        .MAX (23)
    )
    u_alarm_cnt_hour (
        .o_cnt  (o_alarm_hour ),
        .i_clk  (i_hour_clk   ),
        .i_rstn (i_rstn       )
    );

    // 알람 분 (0 ~ 59) 카운터
    alarm_cnt
    #(
        .MAX (59)
    )
    u_alarm_cnt_min (
        .o_cnt  (o_alarm_min  ),
        .i_clk  (i_min_clk    ),
        .i_rstn (i_rstn       )
    );

    // 알람 초 (0 ~ 59) 카운터
    alarm_cnt
    #(
        .MAX (59)
    )
    u_alarm_cnt_sec (
        .o_cnt  (o_alarm_sec  ),
        .i_clk  (i_sec_clk    ),
        .i_rstn (i_rstn       )
    );

    // 알람 ON/OFF 상태 저장
    always @(posedge i_en_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            o_alarm_en <= 1'b0; // 초기 상태: 알람 OFF
        end else begin
            o_alarm_en <= ~o_alarm_en;
        end
    end

    assign o_alarm_ring = o_alarm_en && (i_clock_hour == o_alarm_hour) && (i_clock_min == o_alarm_min) && (i_clock_sec == o_alarm_sec);

endmodule