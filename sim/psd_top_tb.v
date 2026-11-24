`timescale 1ns/1ps
`include "top.v"

module psd_top_tb;

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

defparam u_dut.u_lcd_top.PSD_STABLE = 100;

always #10 i_clk = ~i_clk;

reg [11:0] adc_value;
reg [15:0] adc_frame;
reg [3:0] adc_pos;
reg [3:0] adc_rise;
reg [2:0] adc_addr;

always @(negedge o_adc_csn) begin
    adc_pos = 4'd0;
    adc_rise = 4'd0;
    i_adc_dout = 1'b0;
end

always @(negedge o_adc_sclk) begin
    if(!o_adc_csn) begin
        if(adc_pos == 4'd0) adc_frame = {4'b0000, adc_value};
        i_adc_dout = adc_frame[15 - adc_pos];
        adc_pos = adc_pos + 4'd1;
    end
end

always @(posedge o_adc_sclk) begin
    if(!o_adc_csn) begin
        adc_rise = adc_rise + 4'd1;
        if(adc_rise == 4'd3) adc_addr[2] = o_adc_din;
        if(adc_rise == 4'd4) adc_addr[1] = o_adc_din;
        if(adc_rise == 4'd5) adc_addr[0] = o_adc_din;
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

task set_adc;
    input [11:0] v;
    begin
        adc_value = v;
        #100000;
    end
endtask

initial begin
    $dumpfile("psd_top_tb.vcd");
    $dumpvars(0, psd_top_tb);
    i_clk = 1'b0;
    i_rstn = 1'b0;
    i_sw = 8'hFF;
    i_adc_dout = 1'b0;
    adc_value = 12'd400;
    adc_addr = 3'b111;
    #1000 i_rstn = 1'b1;

    set_adc(12'd400);
    check(u_dut.psd_data == 12'd400, "ADC 400 read as 400");
    check(adc_addr == 3'd0, "ADC channel address 0");
    check(u_dut.psd_near == 1'b0, "far: psd_near 0");
    check(u_dut.u_lcd_top.page == 2'd0, "LCD page TIME");

    set_adc(12'd4095);
    check(u_dut.psd_data == 12'd4095, "ADC 4095 read as 4095");
    check(u_dut.psd_near == 1'b1, "4095: near");
    check(u_dut.u_lcd_top.page == 2'd1, "near -> LCD page ALARM");

    set_adc(12'd1500);
    check(u_dut.psd_data == 12'd1500, "ADC 1500 read as 1500");
    check(u_dut.psd_near == 1'b1, "hysteresis: 1500 keeps near");
    check(u_dut.u_lcd_top.page == 2'd1, "page unchanged while near");

    set_adc(12'd1200);
    check(u_dut.psd_near == 1'b0, "1200: far again");

    set_adc(12'd1700);
    check(u_dut.psd_near == 1'b0, "hysteresis: 1700 stays far");

    set_adc(12'd2600);
    check(u_dut.psd_near == 1'b1, "2600: near");
    check(u_dut.u_lcd_top.page == 2'd2, "near -> LCD page TIMER");

    set_adc(12'd300);
    set_adc(12'd2600);
    check(u_dut.u_lcd_top.page == 2'd0, "near -> LCD page TIME");

    if(err == 0) $display("ALL PASS");
    else $display("%0d FAIL", err);
    $finish;
end

endmodule
