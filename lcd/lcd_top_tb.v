`timescale  1ns/1ps
`define CLKFREQ         50
`define TEXT_FREQDIV    50000
`define PSD_STABLE      100
`define BUSY_SHORT      1
`define BUSY_LONG       4
`define DEBUG
`include    "lcd_top.v"

module  lcd_top_tb;
    wire                o_lcd_e;
    wire                o_lcd_rs;
    wire                o_lcd_rw;
    wire        [7:0]   io_lcd_data;
    wire        [1:0]   o_page;
    reg         [1:0]   i_mode;
    reg                 i_psd;
    reg         [4:0]   i_clock_hour;
    reg         [5:0]   i_clock_min;
    reg         [5:0]   i_clock_sec;
    reg         [4:0]   i_alarm_hour;
    reg         [5:0]   i_alarm_min;
    reg         [5:0]   i_alarm_sec;
    reg                 i_alarm_en;
    reg         [4:0]   i_timer_hour;
    reg         [5:0]   i_timer_min;
    reg         [5:0]   i_timer_sec;
    reg                 i_timer_run;
    reg                 i_clk;
    reg                 i_rstn;

    lcd_top
    #(
        .TEXT_FREQDIV       (`TEXT_FREQDIV      ),
        .PSD_STABLE         (`PSD_STABLE        )
    )
    u_lcd_top(
        .o_lcd_e            (o_lcd_e            ),
        .o_lcd_rs           (o_lcd_rs           ),
        .o_lcd_rw           (o_lcd_rw           ),
        .io_lcd_data        (io_lcd_data        ),
        .o_page             (o_page             ),
        .i_mode             (i_mode             ),
        .i_psd              (i_psd              ),
        .i_clock_hour       (i_clock_hour       ),
        .i_clock_min        (i_clock_min        ),
        .i_clock_sec        (i_clock_sec        ),
        .i_alarm_hour       (i_alarm_hour       ),
        .i_alarm_min        (i_alarm_min        ),
        .i_alarm_sec        (i_alarm_sec        ),
        .i_alarm_en         (i_alarm_en         ),
        .i_timer_hour       (i_timer_hour       ),
        .i_timer_min        (i_timer_min        ),
        .i_timer_sec        (i_timer_sec        ),
        .i_timer_run        (i_timer_run        ),
        .i_clk              (i_clk              ),
        .i_rstn             (i_rstn             )
    );

    always  #(500/`CLKFREQ)     i_clk = ~i_clk;

    reg         [7:0]   ddram[0:127];
    reg         [6:0]   ac;
    reg         [3:0]   busy_cnt;
    reg                 lcd_bf;
    integer             clear_cnt;
    reg         [7:0]   disp_onoff;
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

    task waitOneWrite;
        begin
            wait (u_lcd_top.u_textlcd.c_state == 4'd9);
            wait (u_lcd_top.u_textlcd.c_state == 4'd1);
        end
    endtask

    task psdTouch;
        input   integer n;
        begin
            @(negedge i_clk);   i_psd = 1'b1;
            repeat (n) @(negedge i_clk);
            i_psd = 1'b0;
            repeat (`PSD_STABLE*2) @(negedge i_clk);
        end
    endtask

    reg     [16*8-1:0]  got_line1;
    reg     [16*8-1:0]  got_line2;
    integer             m;
    task checkScreen;
        input   [16*8-1:0]  exp1;
        input   [16*8-1:0]  exp2;
        begin
            waitOneWrite;
            waitOneWrite;
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

    initial begin
        init();
        i_mode = 2'd0;      i_psd = 1'b0;
        i_clock_hour = 5'd12;   i_clock_min = 6'd34;    i_clock_sec = 6'd56;
        i_alarm_hour = 5'd7;    i_alarm_min = 6'd30;    i_alarm_sec = 6'd15;    i_alarm_en  = 1'b1;
        i_timer_hour = 5'd0;    i_timer_min = 6'd3;     i_timer_sec = 6'd0;     i_timer_run = 1'b0;
        resetReleaseAfterNCycles(5);

        checkScreen("MODE: CLOCK     ", "TIME    12:34:56");
        i_clock_sec = 6'd57;
        checkScreen("MODE: CLOCK     ", "TIME    12:34:57");

        psdTouch(`PSD_STABLE*3);
        checkScreen("MODE: CLOCK     ", "ALM 07:30:15 ON ");

        psdTouch(`PSD_STABLE/2);
        checkScreen("MODE: CLOCK     ", "ALM 07:30:15 ON ");

        psdTouch(`PSD_STABLE*3);
        checkScreen("MODE: CLOCK     ", "TMR 00:03:00 STP");

        i_timer_run = 1'b1; i_timer_min = 6'd2;   i_timer_sec = 6'd59;
        checkScreen("MODE: CLOCK     ", "TMR 00:02:59 RUN");

        @(negedge i_clk);   i_psd = 1'b1;
        checkScreen("MODE: CLOCK     ", "TIME    12:34:57");
        checkScreen("MODE: CLOCK     ", "TIME    12:34:57");
        i_psd = 1'b0;
        repeat (`PSD_STABLE*2) @(negedge i_clk);

        i_mode = 2'd2;  i_alarm_hour = 5'd23;   i_alarm_min = 6'd59;    i_alarm_sec = 6'd58;
        checkScreen("MODE: ALARM SET ", "ALM 23:59:58 ON ");

        i_mode = 2'd3;  i_timer_run = 1'b0;     i_timer_hour = 5'd1;    i_timer_min = 6'd0; i_timer_sec = 6'd0;
        checkScreen("MODE: TIMER     ", "TMR 01:00:00 STP");

        psdTouch(`PSD_STABLE*3);
        checkScreen("MODE: TIMER     ", "TIME    12:34:57");

        i_mode = 2'd0;
        checkScreen("MODE: CLOCK     ", "TIME    12:34:57");

        i_mode = 2'd1;
        checkScreen("MODE: CLOCK SET ", "TIME    12:34:57");

        i_mode = 2'd0;  i_alarm_hour = 5'd0;    i_alarm_min = 6'd5;     i_alarm_sec = 6'd0;     i_alarm_en = 1'b0;
        psdTouch(`PSD_STABLE*3);
        checkScreen("MODE: CLOCK     ", "ALM 00:05:00 OFF");

        if (clear_cnt == 1) $display("[PASS] Clear command count = %0d", clear_cnt);
        else begin          $display("[FAIL] Clear command count = %0d", clear_cnt);  err_cnt = err_cnt + 1; end
        if (disp_onoff == 8'h0C) $display("[PASS] Display ON/OFF = 0x%h", disp_onoff);
        else begin               $display("[FAIL] Display ON/OFF = 0x%h", disp_onoff);  err_cnt = err_cnt + 1; end

        $display("==================================================");
        if (err_cnt == 0)   $display("  RESULT : ALL PASS");
        else                $display("  RESULT : %0d FAIL", err_cnt);
        $display("==================================================");
        $finish;
    end

    initial begin
        #(60*1000*1000);
        $display("[FAIL] Timeout");
        $finish;
    end

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
