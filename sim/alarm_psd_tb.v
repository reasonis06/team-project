`timescale 1ns/1ps
`include "top.v"

module alarm_psd_tb;

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
reg i_adc_dout;
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
    .i_adc_dout(i_adc_dout),
    .i_ir_rxb(1'b1),
    .i_sw(i_sw),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

defparam u_dut.u_ctrl.u_ctrl_nco.FREQDIV = 400000;
defparam u_dut.u_ctrl.u_ctrl_debouncer.FREQDIV = 20000;
defparam u_dut.u_lcd_top.PSD_STABLE = 100;

always #10 i_clk = ~i_clk;

reg [11:0] adc_value;
reg [15:0] adc_frame;
reg [3:0] adc_pos;

always @(negedge o_adc_csn) begin
    adc_pos = 4'd0;
    i_adc_dout = 1'b0;
end

always @(negedge o_adc_sclk) begin
    if(!o_adc_csn) begin
        if(adc_pos == 4'd0) adc_frame = {4'b0000, adc_value};
        i_adc_dout = adc_frame[15 - adc_pos];
        adc_pos = adc_pos + 4'd1;
    end
end

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

task wait_sec;
    input integer n;
    begin
        #(n * 8000000);
    end
endtask

integer buzz_edges;
always @(posedge o_buzz) buzz_edges = buzz_edges + 1;

integer k;

initial begin
    $dumpfile("alarm_psd_tb.vcd");
    $dumpvars(1, alarm_psd_tb);
    $dumpvars(1, u_dut);
    i_clk = 1'b0;
    i_rstn = 1'b0;
    i_sw = 8'hFF;
    i_adc_dout = 1'b0;
    adc_value = 12'd300;
    buzz_edges = 0;
    u_dut.u_ctrl.u_ctrl_debouncer.n1 = 8'hFF;
    u_dut.u_ctrl.u_ctrl_debouncer.n2 = 8'hFF;
    #1000 i_rstn = 1'b1;
    @(u_dut.clock_sec);

    button(0);
    button(0);
    check(o_mode == 2'd2, "ALARM_SET mode");
    while(u_dut.u_ctrl.c_targ != 2'd0) button(1);
    for(k = 0; k < 8; k = k + 1) button(2);
    check(u_dut.alarm_sec == 8, "alarm set to 00:00:08");
    button(4);
    check(u_dut.alarm_en == 1'b1, "alarm ON");
    button(0);
    button(0);
    check(o_mode == 2'd0, "back to CLOCK");
    check(u_dut.clock_sec < 8, "clock still before 00:00:08");

    wait(u_dut.clock_sec == 8);
    #100000;
    check(u_dut.alarm_ring == 1'b1, "ring starts at 00:00:08");
    wait_sec(3);
    check(u_dut.alarm_ring == 1'b1, "still ringing 3 s later");
    buzz_edges = 0;
    #20000000;
    check(buzz_edges > 2, "buzzer output toggling");

    adc_value = 12'd1500;
    #200000;
    check(u_dut.alarm_ring == 1'b1, "object far (1500 < TH_ON): keeps ringing");

    adc_value = 12'd2600;
    #200000;
    check(u_dut.alarm_ring == 1'b0, "hand near PSD: alarm stops");
    buzz_edges = 0;
    #20000000;
    check(buzz_edges == 0, "buzzer silent");
    adc_value = 12'd300;
    wait_sec(2);
    check(u_dut.alarm_ring == 1'b0, "stays off after hand removed");

    if(err == 0) $display("ALL PASS");
    else $display("%0d FAIL", err);
    $finish;
end

endmodule
