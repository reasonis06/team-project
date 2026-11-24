`timescale 1ns/1ps
// ==================================================
//  * Filename      : setting_top_tb.v
//  * Description   : 통합 Top 기능 점검
//                    분주비를 defparam으로 줄여 1초를 40us로 만들어 돌림
//
//  실행
//    iverilog -g2012 -I lcd -o setting_top_tb.out setting_top_tb.v
//    vvp setting_top_tb.out
// ==================================================
`include    "setting_top.v"

module setting_top_tb;

// --------------------------------------------------
//  분주비 축소
//    1초  = 2000 clk = 40us
//    버튼 = 160 clk  = 3.2us
// --------------------------------------------------
    defparam    setting_top_tb.u_top.u_ctrl.u_ctrl_nco.FREQDIV = 2000;
    defparam    setting_top_tb.u_top.u_ctrl.u_ctrl_debouncer.u_debouncer_nco.FREQDIV = 20;
    defparam    setting_top_tb.u_top.u_ssegdisp.u_ssegdisp_nco.FREQDIV = 20;
    defparam    setting_top_tb.u_top.u_lcd_top.u_lcd_textgen.u_textgen_nco.FREQDIV = 2000;
    defparam    setting_top_tb.u_top.u_lcd_top.u_textlcd.u_textlcd_nco.FREQDIV = 4;
    defparam    setting_top_tb.u_top.u_psd_stop.HOLD = 200;

// --------------------------------------------------
//  DUT
// --------------------------------------------------
    wire    [5:0]   o_seg_enb;
    wire    [7:0]   o_seg;
    wire            o_buzzer;
    wire            o_sclk;
    wire            o_csn;
    wire            o_din;
    reg             i_dout;
    wire            o_lcd_e;
    wire            o_lcd_rs;
    wire            o_lcd_rw;
    wire    [7:0]   io_lcd_data;
    reg     [7:0]   i_sw;
    reg             i_clk;
    reg             i_rstn;


    setting_top u_top(
        .o_seg_enb  (o_seg_enb  ),
        .o_seg      (o_seg      ),
        .o_buzzer   (o_buzzer   ),
        .o_sclk     (o_sclk     ),
        .o_csn      (o_csn      ),
        .o_din      (o_din      ),
        .i_dout     (i_dout     ),
        .o_lcd_e    (o_lcd_e    ),
        .o_lcd_rs   (o_lcd_rs   ),
        .o_lcd_rw   (o_lcd_rw   ),
        .io_lcd_data(io_lcd_data),
        .i_sw       (i_sw       ),
        .i_clk      (i_clk      ),
        .i_rstn     (i_rstn     )
    );

    localparam  TCLK = 20;
    localparam  TSEC = 2000 * TCLK;

    initial begin
        i_clk = 1'b0;
        forever #(TCLK/2) i_clk = ~i_clk;
    end


// --------------------------------------------------
//  버튼
// --------------------------------------------------
    task press;
        input integer n;
        begin
            i_sw[n] = 1'b0;
            #(80*TCLK);
            i_sw[n] = 1'b1;
            #(80*TCLK);
        end
    endtask

    task press_n;
        input integer n;
        input integer times;
        integer t;
        begin
            for (t=0; t<times; t=t+1) press(n);
        end
    endtask

    task goto_targ;
        input [1:0] want;
        integer g;
        begin
            for (g=0; g<4; g=g+1) begin
                if (u_top.targ != want) press(1);
            end
        end
    endtask

// --------------------------------------------------
//  출력
// --------------------------------------------------
    reg [8*12-1:0] mode_str;
    reg [8*8-1:0]  targ_str;

    always @(*) begin
        case (u_top.mode)
            2'd0:   mode_str = "CLOCK";
            2'd1:   mode_str = "CLOCK_SET";
            2'd2:   mode_str = "ALARM_SET";
            2'd3:   mode_str = "TIMER";
        endcase
    end

    always @(*) begin
        case (u_top.targ)
            2'd0:   targ_str = "SEC";
            2'd1:   targ_str = "MIN";
            2'd2:   targ_str = "HOUR";
            default:targ_str = "?";
        endcase
    end

    task show;
        input [8*24-1:0] tag;
        begin
            $display("[%8t] %-20s mode=%-9s targ=%-4s | clock %02d:%02d.%02d | alarm %02d:%02d.%02d en=%b ring=%b | timer %02d:%02d.%02d run=%b exp=%b | disp %0d%0d %0d%0d.%0d%0d | buzzer=%0s",
                $time, tag, mode_str, targ_str,
                u_top.clock_hour, u_top.clock_min, u_top.clock_sec,
                u_top.alarm_hour, u_top.alarm_min, u_top.alarm_sec,
                u_top.alarm_en, u_top.alarm_ring,
                u_top.timer_hour, u_top.timer_min, u_top.timer_sec, u_top.timer_run, u_top.timer_expire,
                u_top.disp_num[5], u_top.disp_num[4],
                u_top.disp_num[3], u_top.disp_num[2],
                u_top.disp_num[1], u_top.disp_num[0],
                (u_top.buzzer_enb == 1'b0) ? "ON" : "off");
        end
    endtask

// --------------------------------------------------
//  검사
// --------------------------------------------------
    integer err = 0;
    integer prev;
    integer after;
    integer disp_min;
    reg [5:0] target_sec;
    integer ring_len = -1;

    task chk;
        input [8*100-1:0] name;
        input             cond;
        begin
            if (cond) begin
                $display("    [PASS] %0s", name);
            end else begin
                $display("    [FAIL] %0s", name);
                err = err + 1;
            end
        end
    endtask


    // 2행 기대 문자열 : "ALARM HH:MM  ON " / "ALARM HH:MM  OFF"
    function [16*8-1:0] lcd_exp2;
        input dummy;
        reg [7:0] h10, h1, m10, m1;
        begin
            // 연결 연산자 안에서는 폭이 정해진 값만 쓸 수 있어 변수로 받아둠
            h10 = 8'h30 + (u_top.alarm_hour / 10);
            h1  = 8'h30 + (u_top.alarm_hour % 10);
            m10 = 8'h30 + (u_top.alarm_min  / 10);
            m1  = 8'h30 + (u_top.alarm_min  % 10);
            lcd_exp2 = { "ALARM ", h10, h1, ":", m10, m1, "  ",
                         u_top.alarm_en ? "ON " : "OFF" };
        end
    endfunction

    function integer clk_total;
        input dummy;
        begin
            clk_total = u_top.clock_hour*3600 + u_top.clock_min*60 + u_top.clock_sec;
        end
    endfunction

// --------------------------------------------------
//  KS0066 간이 모델 (11주차 / lcd_top_tb.v 에서 가져옴)
//  실제 LCD가 받은 문자를 DDRAM에 쌓아서 화면을 복원함
// --------------------------------------------------
    localparam  BUSY_SHORT = 1;
    localparam  BUSY_LONG  = 4;

    reg     [7:0]   ddram[0:127];
    reg     [6:0]   ac;
    reg     [3:0]   busy_cnt;
    reg             lcd_bf;
    integer         clear_cnt;
    reg     [7:0]   disp_onoff;
    integer         k;

    always @(*) lcd_bf = (busy_cnt != 0) ? 1'b1 : 1'b0;

    assign  io_lcd_data = o_lcd_rw ? {lcd_bf, ac} : 8'hzz;

    always @(negedge o_lcd_e) begin
        if (!i_rstn) begin
        end else if (!o_lcd_rw) begin
            if (o_lcd_rs) begin
                ddram[ac]   = io_lcd_data;
                ac          = ac + 1;
                busy_cnt    = BUSY_SHORT;
            end else begin
                casez (io_lcd_data)
                    8'b1???_????: begin ac = io_lcd_data[6:0];    busy_cnt = BUSY_SHORT; end
                    8'b0000_1???: begin disp_onoff = io_lcd_data; busy_cnt = BUSY_SHORT; end
                    8'b0000_001?: begin ac = 7'h00;               busy_cnt = BUSY_LONG;  end
                    8'b0000_0001: begin
                        for (k=0; k<128; k=k+1) ddram[k] = 8'h20;
                        ac        = 7'h00;
                        busy_cnt  = BUSY_LONG;
                        clear_cnt = clear_cnt + 1;
                    end
                    default     : begin                           busy_cnt = BUSY_SHORT; end
                endcase
            end
        end else begin
            if (busy_cnt != 0) busy_cnt = busy_cnt - 1;
        end
    end

    reg [16*8-1:0] got_line1;
    reg [16*8-1:0] got_line2;
    integer        m;

    // 화면 쓰기 1회 = LINE2_DATA(9) 진입 -> RETURN_HOME(1) 복귀
    task waitOneWrite;
        begin
            wait (u_top.u_lcd_top.u_textlcd.c_state == 4'd9);
            wait (u_top.u_lcd_top.u_textlcd.c_state == 4'd1);
        end
    endtask

    task lcd_check;
        input [16*8-1:0] exp1;
        input [16*8-1:0] exp2;
        begin
            waitOneWrite;       // 입력이 바뀌기 전에 시작된 쓰기일 수 있으므로
            waitOneWrite;       // 한 번 더 기다린 뒤 비교
            for (m=0; m<16; m=m+1) begin
                got_line1[8*(15-m) +: 8] = ddram[7'h00 + m];
                got_line2[8*(15-m) +: 8] = ddram[7'h40 + m];
            end
            if (got_line1 === exp1 && got_line2 === exp2) begin
                $display("    [PASS] LCD \"%s\" / \"%s\"", got_line1, got_line2);
            end else begin
                $display("    [FAIL] LCD \"%s\" / \"%s\"", got_line1, got_line2);
                $display("           기대  \"%s\" / \"%s\"", exp1, exp2);
                err = err + 1;
            end
        end
    endtask

// --------------------------------------------------
//  알람 울림 길이 측정
// --------------------------------------------------
    time ring_start;

    always @(posedge u_top.alarm_ring) begin
        ring_start = $time;
        $display("[%8t] ** 알람 울림 시작 **", $time);
    end

    always @(negedge u_top.alarm_ring) begin
        ring_len = ($time - ring_start) / TSEC;
        $display("[%8t] ** 알람 울림 종료, 지속 %0d 초 **", $time, ring_len);
    end

// --------------------------------------------------
//  본문
// --------------------------------------------------
    initial begin
        i_sw      = 8'hFF;
        i_dout    = 1'b0;
        ac        = 7'h00;
        busy_cnt  = 4'd0;
        clear_cnt = 0;
        disp_onoff= 8'h00;
        for (k=0; k<128; k=k+1) ddram[k] = 8'h20;
        i_rstn = 1'b0;
        #(10*TCLK);
        i_rstn = 1'b1;
        #(2*TCLK);

        $display("==================================================");
        $display(" 1. RESET");
        $display("==================================================");
        show("reset");
        chk("리셋값이 00:00.00",
            (u_top.clock_hour==0) && (u_top.clock_min==0) && (u_top.clock_sec==0));
        chk("리셋 직후 버저 꺼짐", u_top.buzzer_enb == 1'b1);

        #(3*TSEC + TSEC/2);
        $display("");
        $display("==================================================");
        $display(" 2. CLOCK : 시계 진행과 자리올림");
        $display("==================================================");
        show("after 3 sec");
        chk("3초 뒤 초가 3", u_top.clock_sec == 6'd3);

        // 일반 동작에서 59초 -> 다음 분
        force u_top.u_clock.u_clock_cnt_sec.o_cnt = 6'd58;
        #(TCLK); release u_top.u_clock.u_clock_cnt_sec.o_cnt;
        prev = u_top.clock_min;
        #(2*TSEC + TSEC/2);
        show("59 -> 00 roll");
        chk("일반 동작에서 59초 뒤 분이 +1",
            u_top.clock_min == ((prev + 1) % 60));

        $display("");
        $display("==================================================");
        $display(" 3. 모드 전환 시 초가 튀지 않는지");
        $display("==================================================");
        prev = clk_total(0);
        press_n(0, 4);
        after = clk_total(0);
        $display("    모드 4번 전환 전 %0d초 -> 후 %0d초 (실제 경과 약 0.6초)", prev, after);
        chk("모드 전환으로 초가 뛰지 않음", (after - prev) <= 1);
        chk("한 바퀴 돌아 CLOCK 모드", u_top.mode == 2'd0);

        $display("");
        $display("==================================================");
        $display(" 4. CLOCK_SET : 시계 설정");
        $display("==================================================");
        press(0);
        show("sw0");
        chk("mode == CLOCK_SET", u_top.mode == 2'd1);
        chk("모드 바꾸면 자리는 초부터", u_top.targ == 2'd0);

        prev = clk_total(0);
        #(2*TSEC);
        chk("설정 모드에서 시계가 멈춤", clk_total(0) == prev);

        goto_targ(2'd1);
        prev = u_top.clock_min;
        press_n(2, 3);
        show("sw2 x3 (min up)");
        chk("sw2 3번에 분 +3", u_top.clock_min == ((prev + 3) % 60));

        prev = u_top.clock_min;
        press_n(3, 1);
        show("sw3 x1 (min down)");
        chk("sw3 1번에 분 -1", u_top.clock_min == ((prev + 59) % 60));

        goto_targ(2'd2);
        prev = u_top.clock_hour;
        press_n(2, 2);
        show("sw2 x2 (hour up)");
        chk("sw2 2번에 시 +2", u_top.clock_hour == ((prev + 2) % 24));

        // 자리올림 / 자리내림
        goto_targ(2'd0);
        while (u_top.clock_sec != 6'd59) press(2);
        show("sec = 59");
        prev = u_top.clock_min;
        press(2);
        show("sec 59 -> 00");
        chk("초 59에서 올리면 초 00, 분 +1",
            (u_top.clock_sec == 6'd0) && (u_top.clock_min == ((prev + 1) % 60)));

        prev = u_top.clock_min;
        press(3);
        show("sec 00 -> 59");
        chk("초 00에서 내리면 초 59, 분 -1",
            (u_top.clock_sec == 6'd59) && (u_top.clock_min == ((prev + 59) % 60)));

        goto_targ(2'd1);
        while (u_top.clock_min != 6'd59) press(2);
        prev = u_top.clock_hour;
        press(2);
        show("min 59 -> 00");
        chk("분 59에서 올리면 분 00, 시 +1",
            (u_top.clock_min == 6'd0) && (u_top.clock_hour == ((prev + 1) % 24)));

        $display("");
        $display("==================================================");
        $display(" 5. ALARM_SET : 알람 설정");
        $display("==================================================");
        press(0);
        show("sw0");
        chk("mode == ALARM_SET", u_top.mode == 2'd2);
        chk("화면이 알람 값", u_top.disp_num[0] == (u_top.alarm_sec % 10));

        prev = clk_total(0);
        #(2*TSEC);
        chk("알람 설정 중에도 시계는 감", clk_total(0) > prev);

        press(4);
        show("sw4 (alarm on)");
        chk("sw4로 알람 ON", u_top.alarm_en == 1'b1);

        goto_targ(2'd1);
        prev = u_top.alarm_min;
        press_n(2, 5);
        show("sw2 x5 (alarm min up)");
        chk("알람 분 +5", u_top.alarm_min == ((prev + 5) % 60));

        prev = u_top.alarm_min;
        press_n(3, 2);
        show("sw3 x2 (alarm min down)");
        chk("알람 분 -2, 감소가 실제로 동작", u_top.alarm_min == ((prev + 58) % 60));

        $display("");
        $display("==================================================");
        $display(" 6. 알람 울림. 현재 시각 +20초로 맞추고 기다림");
        $display("==================================================");
        while (u_top.clock_sec > 6'd25) #(TSEC);    // 분이 넘어가지 않게

        goto_targ(2'd2);
        while (u_top.alarm_hour != u_top.clock_hour) press(2);
        goto_targ(2'd1);
        while (u_top.alarm_min  != u_top.clock_min ) press(2);
        target_sec = u_top.clock_sec + 6'd20;
        goto_targ(2'd0);
        while (u_top.alarm_sec != target_sec) press(2);
        show("alarm set");

        press_n(0, 2);                  // ALARM_SET -> TIMER -> CLOCK
        show("back to CLOCK");

        #(25*TSEC);
        show("after wait");
        chk("알람이 울렸음", ring_len >= 0);
        $display("    측정된 울림 길이 : %0d 초", ring_len);
        chk("울림이 4~6초 유지", (ring_len >= 4) && (ring_len <= 6));


        $display("");
        $display("==================================================");
        $display(" 7. LCD : 모드와 알람이 화면에 나오는지");
        $display("==================================================");
        // 현재 CLOCK 모드
        lcd_check("MODE: CLOCK     ", lcd_exp2(0));
        show("LCD CLOCK");

        press(0);               // CLOCK_SET
        lcd_check("MODE: CLOCK SET ", lcd_exp2(0));
        press(0);               // ALARM_SET
        lcd_check("MODE: ALARM SET ", lcd_exp2(0));

        press(4);               // 알람 OFF로 토글
        lcd_check("MODE: ALARM SET ", lcd_exp2(0));

        press(4);               // 다시 ON
        lcd_check("MODE: ALARM SET ", lcd_exp2(0));

        goto_targ(2'd1);
        press_n(2, 3);          // 알람 분 +3
        lcd_check("MODE: ALARM SET ", lcd_exp2(0));

        press(0);               // TIMER
        lcd_check("MODE: TIMER     ", lcd_exp2(0));
        chk("LCD 1행이 모드를 따라감", u_top.mode == 2'd3);

        if (clear_cnt == 1) begin
            $display("    [PASS] Clear 명령 %0d회 (리셋 후 1번만)", clear_cnt);
        end else begin
            $display("    [FAIL] Clear 명령 %0d회", clear_cnt);
            err = err + 1;
        end
        chk("Display ON/OFF = 0x0C (커서 꺼짐)", disp_onoff == 8'h0C);

        $display("");
        $display("==================================================");
        $display(" 8. TIMER : 설정과 화면");
        $display("==================================================");
        while (u_top.mode != 2'd3) press(0);
        show("goto TIMER");
        chk("mode == TIMER", u_top.mode == 2'd3);

        goto_targ(2'd1);
        press_n(2, 2);
        show("sw2 x2 (timer min)");
        chk("timer_min == 2", u_top.timer_min == 6'd2);

        disp_min = u_top.disp_num[3]*10 + u_top.disp_num[2];
        $display("    화면 분 %0d / timer_min %0d / alarm_min %0d",
                 disp_min, u_top.timer_min, u_top.alarm_min);
        chk("화면 분 == timer_min", disp_min == u_top.timer_min);

        goto_targ(2'd2);                // HOUR
        press_n(2, 1);
        show("sw2 x1 (timer hour)");
        chk("timer_hour == 1", u_top.timer_hour == 5'd1);
        chk("화면 시 == timer_hour",
            (u_top.disp_num[5]*10 + u_top.disp_num[4]) == u_top.timer_hour);

        $display("");
        $display("==================================================");
        $display(" 9. TIMER : sw5 초기화");
        $display("==================================================");
        press(5);
        show("sw5 (clear)");
        chk("sw5로 00:00:00",
            (u_top.timer_hour == 0) && (u_top.timer_min == 0) && (u_top.timer_sec == 0));

        $display("");
        $display("==================================================");
        $display(" 10. TIMER : 카운트다운과 버저");
        $display("==================================================");
        goto_targ(2'd0);
        press_n(2, 3);
        show("timer = 00.03");
        press(4);
        show("sw4 (start)");
        chk("카운트다운 시작", u_top.timer_run == 1'b1);

        #(TSEC); show("1 sec");
        #(TSEC); show("2 sec");
        #(TSEC); show("3 sec");
        #(TSEC); show("4 sec");
        chk("00:00 도달해 버저 요청", u_top.timer_expire == 1'b1);
        chk("버저 켜짐", u_top.buzzer_enb == 1'b0);

        #(5*TSEC); show("5 sec later");
        chk("약 5초 뒤 버저 꺼짐", u_top.buzzer_enb == 1'b1);

        $display("");
        $display("==================================================");
        $display(" 11. 타이머 동작 중 다른 모드로 전환");
        $display("==================================================");
        press_n(2, 10);
        press(4);
        show("timer start 00.10");
        press(0);                       // TIMER -> CLOCK
        press(0);                       // CLOCK -> CLOCK_SET
        show("CLOCK_SET");
        prev = u_top.timer_min*60 + u_top.timer_sec;
        goto_targ(2'd0);
        press_n(2, 5);
        after = u_top.timer_min*60 + u_top.timer_sec;
        $display("    타이머 %0d초 -> %0d초 (실제 경과 약 0.8초)", prev, after);
        chk("시계 설정 버튼이 타이머를 건드리지 않음", (prev - after) <= 1);

        #(3*TSEC);
        $display("    3초 더 기다린 뒤 타이머 %0d초", u_top.timer_min*60 + u_top.timer_sec);
        chk("다른 모드에서도 타이머가 1초씩 감소",
            (after - (u_top.timer_min*60 + u_top.timer_sec)) >= 2);

        $display("");
        $display("==================================================");
        $display(" 12. PSD : 손을 대면 버저가 꺼지는지");
        $display("==================================================");
        while (u_top.mode != 2'd3) press(0);
        press(5);                       // 타이머 초기화
        goto_targ(2'd0);
        press_n(2, 3);                  // 00:00:03
        press(4);                       // 시작
        show("timer start 00.03");

        #(TSEC); #(TSEC); #(TSEC); #(TSEC);
        show("expired");
        chk("타이머 종료로 버저 켜짐", u_top.buzzer_enb == 1'b0);

        force u_top.u_psd.o_data = 12'h900;     // 손을 가까이 댄 상황
        #(400*TCLK);
        show("PSD hand near");
        chk("PSD가 손을 감지", u_top.psd_near == 1'b1);
        chk("PSD로 버저 정지", u_top.buzzer_enb == 1'b1);
        chk("타이머가 정지 상태로 복귀", u_top.timer_expire == 1'b0);
        release u_top.u_psd.o_data;

        $display("");
        $display("==================================================");
        $display("  FAIL : %0d", err);
        $display("==================================================");
        $finish;
    end

    initial begin
        $dumpfile("setting_top.vcd");
        $dumpvars(0, setting_top_tb);
    end

    initial begin
        #(3000*TSEC);
        $display("TIMEOUT");
        $finish;
    end

endmodule
