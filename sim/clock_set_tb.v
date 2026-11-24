`timescale 1ns/1ps
`include "top.v"

module clock_set_tb;

wire [1:0] o_mode;
wire [5:0] o_seg_enb;
wire [7:0] o_seg;
wire o_lcd_e;
wire o_lcd_rs;
wire o_lcd_rw;
wire [7:0] io_lcd_data;
wire o_buzz;
wire o_adc_sclk;
wire o_adc_csn;
wire o_adc_din;
reg [7:0] i_sw;
reg i_clk;
reg i_rstn;

top
u_dut(
    .o_mode(o_mode),
    .o_seg_enb(o_seg_enb),
    .o_seg(o_seg),
    .o_lcd_e(o_lcd_e),
    .o_lcd_rs(o_lcd_rs),
    .o_lcd_rw(o_lcd_rw),
    .io_lcd_data(io_lcd_data),
    .o_buzz(o_buzz),
    .o_adc_sclk(o_adc_sclk),
    .o_adc_csn(o_adc_csn),
    .o_adc_din(o_adc_din),
    .i_adc_dout(1'b0),
    .i_ir_rxb(1'b1),
    .i_sw(i_sw),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

defparam u_dut.u_ctrl.u_ctrl_nco.FREQDIV = 400000;
defparam u_dut.u_ctrl.u_ctrl_debouncer.FREQDIV = 20000;

always #10 i_clk = ~i_clk;

integer err = 0;

task check;
    input cond;
    input [8*48-1:0] name;
    begin
        if(cond) $display("[PASS] %0s", name);
        else begin
            $display("[FAIL] %0s", name);
            err = err + 1;
        end
    end
endtask

task button;
    input integer k;
    begin
        i_sw[k] = 1'b0;
        #1000000;
        i_sw[k] = 1'b1;
        #1000000;
    end
endtask

task show;
    begin
        $display("        mode=%0d  clock %02d:%02d:%02d", o_mode,
                 u_dut.clock_hour, u_dut.clock_min, u_dut.clock_sec);
    end
endtask

task wait_sec;
    input integer n;
    begin
        #(n * 8000000);
    end
endtask

integer k;
reg [4:0] h0;
reg [5:0] m0;

initial begin
    $dumpfile("clock_set_tb.vcd");
    $dumpvars(1, clock_set_tb);
    $dumpvars(1, u_dut);
    i_clk = 1'b0;
    i_rstn = 1'b0;
    i_sw = 8'hFF;
    u_dut.u_ctrl.u_ctrl_debouncer.n1 = 8'hFF;
    u_dut.u_ctrl.u_ctrl_debouncer.n2 = 8'hFF;
    #1000 i_rstn = 1'b1;

    check(u_dut.clock_hour == 0 && u_dut.clock_min == 0 && u_dut.clock_sec == 0, "reset: 00:00:00");
    @(u_dut.clock_sec);
    #100;
    show;
    check(u_dut.clock_hour == 0 && u_dut.clock_min == 0 && u_dut.clock_sec == 1, "1 s later: 00:00:01");
    wait_sec(2);
    show;

    $display("--- clock set to 00:00:45 with DOWN, then sw[0] x3");
    button(0);
    check(o_mode == 2'd1, "sw[0] -> CLOCK_SET");
    k = 0;
    while(u_dut.clock_sec != 45 && k < 70) begin
        button(3);
        k = k + 1;
    end
    show;
    check(u_dut.clock_hour == 0 && u_dut.clock_min == 0 && u_dut.clock_sec == 45, "set 00:00:45");
    button(0);
    show;
    check(u_dut.clock_hour == 0 && u_dut.clock_min == 0, "CLOCK_SET -> ALARM_SET: hour/min kept");
    button(0);
    show;
    button(0);
    show;
    check(o_mode == 2'd0, "back to CLOCK");
    check(u_dut.clock_hour == 0 && u_dut.clock_min == 0, "back in CLOCK: still 00:00:xx");
    check(u_dut.clock_sec >= 45 && u_dut.clock_sec <= 50, "seconds continue from 45");

    $display("--- same with UP");
    button(0);
    k = 0;
    while(u_dut.clock_sec != 30 && k < 70) begin
        button(2);
        k = k + 1;
    end
    h0 = u_dut.clock_hour;
    m0 = u_dut.clock_min;
    show;
    button(0);
    button(0);
    button(0);
    show;
    check(u_dut.clock_hour == h0 && u_dut.clock_min == m0, "UP case: hour/min kept after modes");

    $display("--- carry: min 59 -> hour");
    button(0);
    button(1);
    check(u_dut.u_ctrl.c_targ == 2'd1, "target -> min");
    button(3);
    check(u_dut.clock_min == 59, "min set to 59");
    button(1);
    button(1);
    k = 0;
    while(u_dut.clock_sec != 57 && k < 70) begin
        button(2);
        k = k + 1;
    end
    show;
    h0 = u_dut.clock_hour;
    button(0);
    button(0);
    button(0);
    wait_sec(4);
    show;
    check(u_dut.clock_hour == ((h0 == 23) ? 0 : h0 + 1) && u_dut.clock_min == 0, "59:5x -> next hour :00");

    $display("--- rollover 23:59:5x -> 00:00:00");
    button(0);
    button(1);
    button(1);
    check(u_dut.u_ctrl.c_targ == 2'd2, "target -> hour");
    while(u_dut.clock_hour != 23) button(3);
    button(1);
    while(u_dut.clock_min != 59) button(3);
    button(1);
    while(u_dut.clock_sec != 57) button(3);
    show;
    check(u_dut.clock_hour == 23 && u_dut.clock_min == 59 && u_dut.clock_sec == 57, "set 23:59:57 without borrow");
    button(0);
    button(0);
    button(0);
    wait_sec(4);
    show;
    check(u_dut.clock_hour == 0 && u_dut.clock_min == 0, "23:59:5x -> 00:00:xx");

    $display("--- timer still counts in TIMER mode");
    button(0);
    button(0);
    button(0);
    check(o_mode == 2'd3, "TIMER mode");
    button(2);
    button(2);
    button(2);
    check(u_dut.timer_sec == 3 || u_dut.timer_min != 0, "timer set");
    button(4);
    check(u_dut.timer_run == 1'b1, "timer start");
    wait_sec(4);
    check(u_dut.timer_expire == 1'b1 || (u_dut.timer_sec == 0 && u_dut.timer_min == 0), "timer reached 00:00");

    if(err == 0) $display("ALL PASS");
    else $display("%0d FAIL", err);
    $finish;
end

endmodule
