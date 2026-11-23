// ==================================================
//  * Filename      : timer_tb.v
// ==================================================
`timescale  1ns/1ns
`define CLKFREQ     50
`include    "../timer.v"

module  timer_tb;
    wire    [5:0]   o_min;
    wire    [5:0]   o_sec;
    wire            o_run;
    wire            o_expire;
    reg             i_set_en;
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
        .EXPIRE_SEC (3              )
    )
    u_timer(
        .o_min      (o_min          ),
        .o_sec      (o_sec          ),
        .o_run      (o_run          ),
        .o_expire   (o_expire       ),
        .i_set_en   (i_set_en       ),
        .i_set_min  (i_set_min      ),
        .i_set_sec  (i_set_sec      ),
        .i_set_dec  (i_set_dec      ),
        .i_tick     (i_tick         ),
        .i_start    (i_start        ),
        .i_clear    (i_clear        ),
        .i_clk      (i_clk          ),
        .i_rstn     (i_rstn         )
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

    task press;
        input integer sel;      // 0:set_min 1:set_sec 2:start 3:clear
        begin
            case (sel)
                0: i_set_min = 1'b1;
                1: i_set_sec = 1'b1;
                2: i_start   = 1'b1;
                3: i_clear   = 1'b1;
            endcase
            #200;
            i_set_min = 1'b0;  i_set_sec = 1'b0;
            i_start   = 1'b0;  i_clear   = 1'b0;
            #200;
        end
    endtask

    initial begin
        i_clk=1; i_rstn=0;
        i_set_en=0; i_set_min=0; i_set_sec=0; i_set_dec=0;
        i_start=0; i_clear=0;
        #100 i_rstn = 1;

        $display("--- 1) 설정: 분 1회, 초 2회 증가 -> 01:02 ---");
        i_set_en = 1'b1;
        press(0);                   // min +1
        press(1); press(1);         // sec +2
        $display("    설정값 = %02d:%02d", o_min, o_sec);

        $display("--- 2) 감소 스위치 확인: 초 1회 감소 -> 01:01 ---");
        i_set_dec = 1'b1;
        press(1);
        i_set_dec = 1'b0;
        $display("    설정값 = %02d:%02d", o_min, o_sec);

        $display("--- 3) 시작 ---");
        i_set_en = 1'b0;
        press(2);
        $display("    o_run = %b", o_run);

        #40000;
        $display("--- 4) 종료 후 상태: %02d:%02d  run=%b expire=%b",
                 o_min, o_sec, o_run, o_expire);
        $finish;
    end

//  매 tick마다 남은 시간 출력
    always @(posedge i_tick) begin
        if (i_rstn) begin
            $display("  t=%7t  %02d:%02d  run=%b expire=%b",
                     $time, o_min, o_sec, o_run, o_expire);
        end
    end

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars;
    end
endmodule
