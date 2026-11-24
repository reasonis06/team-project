// ==================================================
//  * Filename      : timer_tb.v
//  * Description   : timer 단독 테스트벤치 (HH:MM:SS)
//                    설정(증가/감소/랩어라운드) -> 01:01:01 시작
//                    -> 매 초 정확히 1초씩 감소하는지 자동 검사
//                    -> 분/시 빌림 -> 00:00:00 버저 요청 -> 해제
//                    마지막 줄에 RESULT : ALL PASS / FAIL n
// ==================================================
`timescale  1ns/1ns
`define CLKFREQ     50
`include    "../timer.v"

module  timer_tb;
    wire    [4:0]   o_hour;
    wire    [5:0]   o_min;
    wire    [5:0]   o_sec;
    wire            o_run;
    wire            o_expire;
    wire            o_expire_start;
    reg             i_set_en;
    reg             i_set_hour;
    reg             i_set_min;
    reg             i_set_sec;
    reg             i_set_dec;
    reg             i_tick;
    reg             i_start;
    reg             i_clear;
    reg             i_clk;
    reg             i_rstn;

    timer
    #(
        .EXPIRE_SEC     (3              )
    )
    u_timer(
        .o_hour         (o_hour         ),
        .o_min          (o_min          ),
        .o_sec          (o_sec          ),
        .o_run          (o_run          ),
        .o_expire       (o_expire       ),
        .o_expire_start (o_expire_start ),
        .i_set_en       (i_set_en       ),
        .i_set_hour     (i_set_hour     ),
        .i_set_min      (i_set_min      ),
        .i_set_sec      (i_set_sec      ),
        .i_set_dec      (i_set_dec      ),
        .i_tick         (i_tick         ),
        .i_start        (i_start        ),
        .i_clear        (i_clear        ),
        .i_clk          (i_clk          ),
        .i_rstn         (i_rstn         )
    );

    always  #(500/`CLKFREQ)     i_clk = ~i_clk;

//  시뮬레이션용 빠른 1Hz: 2us 주기
    initial begin
        i_tick = 1'b0;
        forever begin
            #1000   i_tick = 1'b1;
            #1000   i_tick = 1'b0;
        end
    end

// --------------------------------------------------
//  검사 도구
// --------------------------------------------------
    integer fail_cnt = 0;
    integer expire_pulse_cnt = 0;

    task check;
        input           cond;
        input [8*48-1:0] msg;   // 메시지는 영문 (iverilog에서 reg 문자열의 한글이 깨짐)
        begin
            if (cond) $display("    [PASS] %0s", msg);
            else begin
                $display("    [FAIL] %0s  (현재 %02d:%02d:%02d run=%b expire=%b)",
                         msg, o_hour, o_min, o_sec, o_run, o_expire);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    task press;
        input integer sel;      // 0:set_min 1:set_sec 2:start 3:clear 4:set_hour
        begin
            case (sel)
                0: i_set_min  = 1'b1;
                1: i_set_sec  = 1'b1;
                2: i_start    = 1'b1;
                3: i_clear    = 1'b1;
                4: i_set_hour = 1'b1;
            endcase
            #200;
            i_set_min = 1'b0;  i_set_sec  = 1'b0;  i_set_hour = 1'b0;
            i_start   = 1'b0;  i_clear    = 1'b0;
            #200;
        end
    endtask

// --------------------------------------------------
//  동작 중 매 초 감소량 검사: 남은 총 초가 정확히 1씩 줄어야 함
// --------------------------------------------------
    integer total, prev_total, step_err, step_cnt;
    initial begin prev_total = -1; step_err = 0; step_cnt = 0; end

    always @(posedge i_clk) begin
        total = o_hour * 3600 + o_min * 60 + o_sec;
        if ((o_run || o_expire) && (prev_total >= 0) && (total != prev_total)) begin
            step_cnt = step_cnt + 1;
            if (total != prev_total - 1) begin
                step_err = step_err + 1;
                $display("    [FAIL] 감소 오류: %0d초 -> %0d초", prev_total, total);
            end
            //  빌림 지점 출력
            if ((o_sec == 6'd59) || (total <= 2)) begin
                $display("  t=%9t  %02d:%02d:%02d", $time, o_hour, o_min, o_sec);
            end
        end
        prev_total = total;
        if (o_expire_start) expire_pulse_cnt = expire_pulse_cnt + 1;
    end

// --------------------------------------------------
//  시나리오
// --------------------------------------------------
    initial begin
        i_clk=0; i_rstn=0;          // 0으로 시작: 입력 변경 시점이 클럭 상승엣지와 겹치지 않게
        i_set_en=0; i_set_hour=0; i_set_min=0; i_set_sec=0; i_set_dec=0;
        i_start=0; i_clear=0;
        #100 i_rstn = 1;

        $display("--- 1) 설정: 분 +1, 초 +2 -> 00:01:02 ---");
        i_set_en = 1'b1;
        press(0);
        press(1); press(1);
        check((o_hour == 0) && (o_min == 1) && (o_sec == 2), "00:01:02");

        $display("--- 2) 초 감소 -> 00:01:01 ---");
        i_set_dec = 1'b1;  press(1);  i_set_dec = 1'b0;
        check((o_hour == 0) && (o_min == 1) && (o_sec == 1), "00:01:01");

        $display("--- 3) 시 감소 랩어라운드 00 -> 23 ---");
        i_set_dec = 1'b1;  press(4);  i_set_dec = 1'b0;
        check(o_hour == 23, "hour 23");

        $display("--- 4) 시 증가 x2: 23 -> 00 -> 01 ---");
        press(4); press(4);
        check((o_hour == 1) && (o_min == 1) && (o_sec == 1), "01:01:01");

        $display("--- 5) set_en=0 이면 설정 무시 ---");
        i_set_en = 1'b0;  press(4);  i_set_en = 1'b1;
        check(o_hour == 1, "set_en=0: hour stays 01");

        $display("--- 6) 시작 (ctrl 통합 조건: set_en=1 유지) ---");
        press(2);
        check(o_run == 1'b1, "o_run = 1");

        $display("--- 7) 동작 중 설정 입력 무시 ---");
        press(4); press(0);
        check(o_hour == 1, "running: hour stays 01");

        wait (o_expire);
        repeat (2) @(negedge i_clk);    // 마지막 감소가 집계되도록 대기, 이후 입력은 하강엣지 기준
        $display("--- 8) 00:00:00 도달 ---");
        check((o_hour == 0) && (o_min == 0) && (o_sec == 0), "00:00:00");
        check(o_run == 1'b0, "o_run = 0");
        check(step_err == 0, "every step is exactly -1s");
        check(step_cnt == 3661, "3661 steps from 01:01:01");

        wait (!o_expire);
        @(negedge i_clk);   // 입력 변경이 상승엣지와 겹치지 않게
        $display("--- 9) EXPIRE_SEC 후 버저 해제 ---");
        check(expire_pulse_cnt == 1, "o_expire_start pulsed once");
        check((o_run == 1'b0) && (o_expire == 1'b0), "back to idle");

        $display("--- 10) 00:00:00에서는 시작 안 됨 ---");
        press(2);
        check(o_run == 1'b0, "o_run stays 0");

        $display("--- 11) 동작 중 초기화 ---");
        press(4); press(2);
        check(o_run == 1'b1, "01:00:00 started");
        press(3);
        check((o_run == 1'b0) && (o_hour == 0) && (o_min == 0) && (o_sec == 0), "clear -> 00:00:00 idle");

        $display("");
        if (fail_cnt == 0) $display("RESULT : ALL PASS");
        else               $display("RESULT : FAIL %0d", fail_cnt);
        $finish;
    end

    initial begin
        #20000000;
        $display("!!! 타임아웃: 00:00:00에 도달하지 못함");
        $display("RESULT : FAIL (timeout)");
        $finish;
    end
endmodule
