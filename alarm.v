// ==================================================
//  * Filename      : alarm.v
//  * Description   : 알람 시각 저장, ON/OFF, 울림 유지
//
//  포트는 원본과 같음. 아래 4개를 추가했음
//    i_down : 알람 값 감소
//    i_tick : 1Hz 1클럭 펄스. 울림 유지 시간을 세는 데 씀
//    i_clk  : 50MHz 시스템 클럭
//    i_stop : 울림 정지 펄스
//
//  달라진 점
//    울림 유지 카운터 추가. 시각이 맞으면 RING_SEC초 동안 o_alarm_ring을 1로 둠
//    원본은 시·분·초가 같은 1초 동안만 1이라 버저가 한 번 울리고 끝이었음
//    울리는 중에 알람을 OFF로 바꾸거나 i_stop(PSD)이 들어오면 바로 멈춤
// ==================================================
`include "alarm_cnt.v"

module alarm
#(
    parameter RING_SEC = 60         // 울림 유지 시간(초)
)
(
    // 1. LCD 및 Top으로 전달할 출력
    output     [4:0] o_alarm_hour,  // 알람 시 (0~23)
    output     [5:0] o_alarm_min,   // 알람 분 (0~59)
    output     [5:0] o_alarm_sec,   // 알람 초 (0~59)
    output reg       o_alarm_en,    // 알람 켜짐(1), 꺼짐(0)
    output           o_alarm_ring,  // 1: 알람 울리는 중

    // 2. 현재 시각 입력
    input      [4:0] i_clock_hour,
    input      [5:0] i_clock_min,
    input      [5:0] i_clock_sec,

    // 3. 알람 설정 입력
    input            i_hour_clk,    // 알람 시 변경 펄스
    input            i_min_clk,     // 알람 분 변경 펄스
    input            i_sec_clk,     // 알람 초 변경 펄스
    input            i_en_clk,      // 알람 ON/OFF 토글 펄스
    input            i_down,        // 1이면 감소
    input            i_tick,        // 1Hz 1클럭 펄스
    input            i_stop,
    input            i_clk,
    input            i_rstn
);

    // 알람 시 (0 ~ 23) 카운터
    alarm_cnt
    #(
        .MAX (23)
    )
    u_alarm_cnt_hour (
        .o_cnt  (o_alarm_hour ),
        .i_en   (i_hour_clk   ),
        .i_down (i_down       ),
        .i_clk  (i_clk        ),
        .i_rstn (i_rstn       )
    );

    // 알람 분 (0 ~ 59) 카운터
    alarm_cnt
    #(
        .MAX (59)
    )
    u_alarm_cnt_min (
        .o_cnt  (o_alarm_min  ),
        .i_en   (i_min_clk    ),
        .i_down (i_down       ),
        .i_clk  (i_clk        ),
        .i_rstn (i_rstn       )
    );

    // 알람 초 (0 ~ 59) 카운터
    alarm_cnt
    #(
        .MAX (59)
    )
    u_alarm_cnt_sec (
        .o_cnt  (o_alarm_sec  ),
        .i_en   (i_sec_clk    ),
        .i_down (i_down       ),
        .i_clk  (i_clk        ),
        .i_rstn (i_rstn       )
    );

    // 알람 ON/OFF 상태 저장
    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            o_alarm_en <= 1'b0;     // 초기 상태: 알람 OFF
        end else if (i_en_clk) begin
            o_alarm_en <= ~o_alarm_en;
        end
    end

    // 울림 유지
    wire       match;
    reg        ringing;
    reg        match_d;
    reg  [$clog2(RING_SEC+1)-1:0] ring_cnt;

    assign match = o_alarm_en
                && (i_clock_hour == o_alarm_hour)
                && (i_clock_min  == o_alarm_min )
                && (i_clock_sec  == o_alarm_sec );

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            match_d  <= 1'b0;
            ringing  <= 1'b0;
            ring_cnt <= 0;
        end else begin
            match_d <= match;
            if (!ringing) begin
                if (match && !match_d) begin
                    ringing  <= 1'b1;
                    ring_cnt <= 0;
                end
            end else begin
                if (!o_alarm_en || i_stop) begin
                    ringing  <= 1'b0;
                    ring_cnt <= 0;
                end else if (i_tick) begin
                    if (ring_cnt == RING_SEC - 1) begin
                        ringing  <= 1'b0;
                        ring_cnt <= 0;
                    end else begin
                        ring_cnt <= ring_cnt + 1'b1;
                    end
                end
            end
        end
    end

    assign o_alarm_ring = ringing;

endmodule
