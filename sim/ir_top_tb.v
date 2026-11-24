`timescale 1ns/1ps
`include "top.v"

`define IR_SCALE 80

module ir_top_tb;

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
reg i_ir_rxb;
reg [7:0] i_sw;
reg i_clk;
reg i_rstn;

top
#(
    .IR_FREQDIV(4),
    .IR_HOLD(100000)
)
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
    .i_ir_rxb(i_ir_rxb),
    .i_sw(i_sw),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

defparam u_dut.u_ctrl.u_ctrl_nco.FREQDIV = 4000000;
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

task ir_mark;
    input integer us;
    begin
        i_ir_rxb = 1'b0;
        #(us * `IR_SCALE);
    end
endtask

task ir_space;
    input integer us;
    begin
        i_ir_rxb = 1'b1;
        #(us * `IR_SCALE);
    end
endtask

task ir_byte;
    input [7:0] b;
    integer n;
    begin
        for(n = 0; n < 8; n = n + 1) begin
            ir_mark(560);
            if(b[n]) ir_space(1690);
            else ir_space(560);
        end
    end
endtask

task ir_send;
    input [7:0] cmd;
    input [7:0] cmd_n;
    begin
        ir_mark(9000);
        ir_space(4500);
        ir_byte(8'h40);
        ir_byte(8'hBF);
        ir_byte(cmd);
        ir_byte(cmd_n);
        ir_mark(560);
        ir_space(40000);
    end
endtask

task ir_key;
    input [7:0] code;
    reg [7:0] b;
    integer n;
    begin
        for(n = 0; n < 8; n = n + 1) b[n] = code[7 - n];
        ir_send(b, ~b);
    end
endtask

task ir_repeat;
    begin
        ir_mark(9000);
        ir_space(2250);
        ir_mark(560);
        ir_space(40000);
    end
endtask

task button;
    input integer k;
    begin
        i_sw[k] = 1'b0;
        #2000000;
        i_sw[k] = 1'b1;
        #2000000;
    end
endtask

reg [5:0] sec0;

initial begin
    $dumpfile("ir_top_tb.vcd");
    $dumpvars(0, ir_top_tb);
    i_clk = 1'b0;
    i_rstn = 1'b0;
    i_sw = 8'hFF;
    i_ir_rxb = 1'b1;
    u_dut.u_ctrl.u_ctrl_debouncer.n1 = 8'hFF;
    u_dut.u_ctrl.u_ctrl_debouncer.n2 = 8'hFF;
    #1000 i_rstn = 1'b1;
    #100000;

    check(o_mode == 2'd0, "start: CLOCK mode");

    ir_key(8'h40);
    check(u_dut.ir_data[23:0] == 24'hFD40BF, "MENU frame shows FD40BF (same as table)");
    check(o_mode == 2'd1, "remote MENU -> CLOCK_SET");

    sec0 = u_dut.clock_sec;
    ir_key(8'hB0);
    check(u_dut.clock_sec == ((sec0 == 0) ? 59 : sec0 - 1), "remote DOWN(-) -> clock sec - 1");

    ir_key(8'h08);
    check(o_mode == 2'd2, "remote key 1 -> ALARM_SET");

    ir_send(8'h15, 8'h00);
    check(u_dut.alarm_sec == 0, "bad checksum frame ignored");

    ir_repeat;
    check(u_dut.alarm_sec == 0 && o_mode == 2'd2, "repeat code ignored");

    ir_key(8'h00);
    check(u_dut.alarm_sec == 0 && o_mode == 2'd2, "unknown key ignored");

    ir_key(8'hA0);
    check(u_dut.alarm_sec == 1, "remote UP(+) -> alarm sec 1");

    ir_key(8'h50);
    check(u_dut.u_ctrl.c_targ == 2'd1, "remote TARG(>>|) -> min");

    ir_key(8'h48);
    check(u_dut.alarm_min == 1, "remote key 3 -> alarm min 1");

    button(2);
    check(u_dut.alarm_min == 2, "board button UP still works");

    button(3);
    check(u_dut.alarm_min == 1, "board button DOWN -> alarm min 1");

    ir_key(8'hB0);
    check(u_dut.alarm_min == 0, "remote DOWN(-) -> alarm min 0");

    ir_key(8'hB0);
    check(u_dut.alarm_min == 59, "remote DOWN -> alarm min wraps to 59");

    button(2);
    check(u_dut.alarm_min == 0, "button UP -> alarm min 0");

    ir_key(8'h90);
    check(u_dut.alarm_en == 1'b1, "remote OK(>||) -> alarm ON");

    ir_key(8'h40);
    check(o_mode == 2'd3, "remote MODE -> TIMER");

    ir_key(8'h50);
    check(u_dut.u_ctrl.c_targ == 2'd1, "remote TARG -> timer min");

    ir_key(8'hA0);
    check(u_dut.timer_min == 1, "remote UP -> timer min 1");

    ir_key(8'h90);
    check(u_dut.timer_run == 1'b1, "remote OK -> timer start");

    ir_key(8'h90);
    check(u_dut.timer_run == 1'b0, "remote OK again -> timer pause");

    ir_key(8'h60);
    check(u_dut.timer_min == 0 && u_dut.timer_sec == 0, "remote CLR(EQ) -> timer 00:00:00");

    if(err == 0) $display("ALL PASS");
    else $display("%0d FAIL", err);
    $finish;
end

endmodule
