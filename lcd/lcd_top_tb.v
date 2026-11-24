// ==================================================
//  * Filename      : lcd_top_tb.v
//  * Description   : 팀프로젝트 LCD 파트 테스트벤치
//                    - week11 top_tb.v의 KS0066 간이 모델(BF/AC/DDRAM) 재사용
//                    - 모드/알람 입력을 바꿔 가며 LCD 화면을 기대 문구와 자동 비교
//                    - Clear 명령이 리셋 후 1번만 나가는지, Display ON/OFF = 0x0C인지 확인
//  * Sim time      : TEXT_FREQDIV=50,000 → 갱신 주기 1ms
// ==================================================
`timescale  1ns/1ps
`define CLKFREQ         50          // Clock Freq. (Unit: MHz)
`define TEXT_FREQDIV    50000       // 50MHz / 50,000 = 1kHz (시뮬레이션 단축용)
`define BUSY_SHORT      1           // 일반 쓰기 후 BF=1 읽기 횟수
`define BUSY_LONG       4           // Clear / Return Home 후 BF=1 읽기 횟수
`define DEBUG
`include    "lcd_top.v"

module  lcd_top_tb;
// --------------------------------------------------
//  DUT Signals & Instantiation
// --------------------------------------------------
    wire                o_lcd_e;
    wire                o_lcd_rs;
    wire                o_lcd_rw;
    wire        [7:0]   io_lcd_data;
    reg         [1:0]   i_mode;
    reg         [4:0]   i_alarm_hour;
    reg         [5:0]   i_alarm_min;
    reg                 i_alarm_en;
    reg                 i_clk;
    reg                 i_rstn;

    lcd_top
    #(
        .TEXT_FREQDIV       (`TEXT_FREQDIV      )
    )
    u_lcd_top(
        .o_lcd_e            (o_lcd_e            ),
        .o_lcd_rs           (o_lcd_rs           ),
        .o_lcd_rw           (o_lcd_rw           ),
        .io_lcd_data        (io_lcd_data        ),
        .i_mode             (i_mode             ),
        .i_alarm_hour       (i_alarm_hour       ),
        .i_alarm_min        (i_alarm_min        ),
        .i_alarm_en         (i_alarm_en         ),
        .i_clk              (i_clk              ),
        .i_rstn             (i_rstn             )
    );

    always  #(500/`CLKFREQ)     i_clk = ~i_clk;

// --------------------------------------------------
//  KS0066 간이 모델 (week11 top_tb.v 재사용)
// --------------------------------------------------
    reg         [7:0]   ddram[0:127];
    reg         [6:0]   ac;
    reg         [3:0]   busy_cnt;
    reg                 lcd_bf;
    integer             clear_cnt;      // Clear 명령 횟수
    reg         [7:0]   disp_onoff;     // 마지막 Display ON/OFF 명령 값
    integer             k;

    always @(*) lcd_bf = (busy_cnt != 0) ? 1'b1 : 1'b0;

    assign  io_lcd_data = o_lcd_rw ? {lcd_bf, ac} : 8'hzz;

    always @(negedge o_lcd_e) begin
        if (!i_rstn) begin
        end else if (!o_lcd_rw) begin
            if (o_lcd_rs) begin
                ddram[ac]   = io_lcd_data;
                ac          = ac + 1;
                busy_cnt    = `BUSY_SHORT;
            end else begin
                casez (io_lcd_data)
                    8'b1???_????: begin ac = io_lcd_data[6:0];  busy_cnt = `BUSY_SHORT; end
                    8'b0000_1???: begin disp_onoff = io_lcd_data; busy_cnt = `BUSY_SHORT; end
                    8'b0000_001?: begin ac = 7'h00;             busy_cnt = `BUSY_LONG;  end
                    8'b0000_0001: begin
                        for (k=0; k<128; k=k+1) ddram[k] = 8'h20;
                        ac          = 7'h00;
                        busy_cnt    = `BUSY_LONG;
                        clear_cnt   = clear_cnt + 1;
                    end
                    default     : begin                         busy_cnt = `BUSY_SHORT; end
                endcase
            end
        end else begin
            if (busy_cnt != 0) busy_cnt = busy_cnt - 1;
        end
    end

// --------------------------------------------------
//  Tasks
// --------------------------------------------------
    integer             err_cnt;

    task init;
        begin
            i_clk = 1'b1;   i_rstn = 1'b1;
            ac = 7'h00;     busy_cnt = 4'd0;
            clear_cnt = 0;  disp_onoff = 8'h00;     err_cnt = 0;
            for (k=0; k<128; k=k+1) ddram[k] = 8'h20;
        end
    endtask

    task resetReleaseAfterNCycles;
        input   [3:0]   n;
        begin
            i_rstn  = 1'b0;
            #(n*1000/`CLKFREQ);
            i_rstn  = 1'b1;
        end
    endtask

    // 화면 쓰기 1회 = LINE2_DATA(9) 진입 → RETURN_HOME(1) 복귀
    task waitOneWrite;
        begin
            wait (u_lcd_top.u_textlcd.c_state == 4'd9);
            wait (u_lcd_top.u_textlcd.c_state == 4'd1);
        end
    endtask

    reg     [16*8-1:0]  got_line1;
    reg     [16*8-1:0]  got_line2;
    integer             m;
    task checkScreen;
        input   [16*8-1:0]  exp1;
        input   [16*8-1:0]  exp2;
        begin
            waitOneWrite;               // 입력 변경 전에 시작된 쓰기일 수 있으므로
            waitOneWrite;               // 한 번 더 기다린 뒤 비교
            for (m=0; m<16; m=m+1) begin
                got_line1[8*(15-m) +: 8] = ddram[7'h00 + m];
                got_line2[8*(15-m) +: 8] = ddram[7'h40 + m];
            end
            if (got_line1 === exp1 && got_line2 === exp2) begin
                $display("[%8.1f us] [PASS] \"%s\" / \"%s\"", $realtime/1000.0, got_line1, got_line2);
            end else begin
                $display("[%8.1f us] [FAIL] got \"%s\" / \"%s\"", $realtime/1000.0, got_line1, got_line2);
                $display("                        exp \"%s\" / \"%s\"", exp1, exp2);
                err_cnt = err_cnt + 1;
            end
        end
    endtask

// --------------------------------------------------
//  Test Stimulus
// --------------------------------------------------
    initial begin
        init();
        i_mode = 2'd0;  i_alarm_hour = 5'd7;    i_alarm_min = 6'd30;    i_alarm_en = 1'b1;
        resetReleaseAfterNCycles(5);

        checkScreen("MODE: CLOCK     ", "ALARM 07:30  ON ");

        i_mode = 2'd1;
        checkScreen("MODE: CLOCK SET ", "ALARM 07:30  ON ");

        i_mode = 2'd2;  i_alarm_hour = 5'd23;   i_alarm_min = 6'd59;
        checkScreen("MODE: ALARM SET ", "ALARM 23:59  ON ");

        i_mode = 2'd3;  i_alarm_hour = 5'd0;    i_alarm_min = 6'd5;     i_alarm_en = 1'b0;
        checkScreen("MODE: TIMER     ", "ALARM 00:05  OFF");

        i_mode = 2'd0;  i_alarm_en = 1'b1;
        checkScreen("MODE: CLOCK     ", "ALARM 00:05  ON ");

        // 초기화 명령 확인
        if (clear_cnt == 1) $display("[PASS] Clear 명령 %0d회 (리셋 후 1번만)", clear_cnt);
        else begin          $display("[FAIL] Clear 명령 %0d회", clear_cnt);  err_cnt = err_cnt + 1; end
        if (disp_onoff == 8'h0C) $display("[PASS] Display ON/OFF = 0x%h (커서 OFF)", disp_onoff);
        else begin               $display("[FAIL] Display ON/OFF = 0x%h", disp_onoff);  err_cnt = err_cnt + 1; end

        $display("==================================================");
        if (err_cnt == 0)   $display("  RESULT : ALL PASS");
        else                $display("  RESULT : %0d FAIL", err_cnt);
        $display("==================================================");
        $finish;
    end

    initial begin
        #(30*1000*1000);
        $display("[FAIL] Timeout");
        $finish;
    end

// --------------------------------------------------
//  Dump VCD
// --------------------------------------------------
    reg [8*32-1:0]  vcd_file;
    initial begin
        if ($value$plusargs("vcd=%s", vcd_file)) begin
            $dumpfile(vcd_file);
            $dumpvars;
        end else begin
            $dumpfile("lcd_top_tb.vcd");
            $dumpvars;
        end
    end

endmodule
