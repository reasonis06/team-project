`timescale 1ns/1ps
`include "alarm.v"

module alarm_tb;

wire [4:0] o_alarm_hour;
wire [5:0] o_alarm_min;
wire [5:0] o_alarm_sec;
wire o_alarm_en;
wire o_alarm_ring;
reg [4:0] i_clock_hour;
reg [5:0] i_clock_min;
reg [5:0] i_clock_sec;
reg i_hour_clk;
reg i_min_clk;
reg i_sec_clk;
reg i_en_clk;
reg i_down;
reg i_tick;
reg i_stop;
reg i_clk;
reg i_rstn;

alarm
#(
    .RING_SEC(5)
)
u_alarm(
    .o_alarm_hour(o_alarm_hour),
    .o_alarm_min(o_alarm_min),
    .o_alarm_sec(o_alarm_sec),
    .o_alarm_en(o_alarm_en),
    .o_alarm_ring(o_alarm_ring),
    .i_clock_hour(i_clock_hour),
    .i_clock_min(i_clock_min),
    .i_clock_sec(i_clock_sec),
    .i_hour_clk(i_hour_clk),
    .i_min_clk(i_min_clk),
    .i_sec_clk(i_sec_clk),
    .i_en_clk(i_en_clk),
    .i_down(i_down),
    .i_tick(i_tick),
    .i_stop(i_stop),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

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

task pulse_sec;  begin @(negedge i_clk) i_sec_clk = 1;  @(negedge i_clk) i_sec_clk = 0;  end endtask
task pulse_hour; begin @(negedge i_clk) i_hour_clk = 1; @(negedge i_clk) i_hour_clk = 0; end endtask
task pulse_en;   begin @(negedge i_clk) i_en_clk = 1;   @(negedge i_clk) i_en_clk = 0;   end endtask
task pulse_stop; begin @(negedge i_clk) i_stop = 1;     @(negedge i_clk) i_stop = 0;     end endtask

task tick_to;
    input [5:0] s;
    begin
        @(negedge i_clk) begin i_clock_sec = s; i_tick = 1; end
        @(negedge i_clk) i_tick = 0;
        repeat(4) @(negedge i_clk);
    end
endtask

initial begin
    $dumpfile("alarm_tb.vcd");
    $dumpvars(0, alarm_tb);
    i_clk = 0; i_rstn = 0;
    i_clock_hour = 0; i_clock_min = 0; i_clock_sec = 0;
    i_hour_clk = 0; i_min_clk = 0; i_sec_clk = 0;
    i_en_clk = 0; i_down = 0; i_tick = 0; i_stop = 0;
    #100 i_rstn = 1; #100;

    i_down = 1; pulse_hour; i_down = 0;
    check(o_alarm_hour == 23, "alarm hour down 0 -> 23");
    i_down = 1; pulse_sec; pulse_sec; i_down = 0;
    check(o_alarm_sec == 58, "alarm sec down 0 -> 58");
    pulse_sec; pulse_sec; pulse_sec; pulse_sec; pulse_sec;
    check(o_alarm_sec == 3, "alarm sec up 58 -> 3");
    pulse_hour;
    check(o_alarm_hour == 0, "alarm hour up 23 -> 0");

    tick_to(3);
    check(o_alarm_ring == 0, "no ring while alarm OFF");
    tick_to(0);
    pulse_en;
    check(o_alarm_en == 1, "alarm ON");

    tick_to(1); tick_to(2);
    check(o_alarm_ring == 0, "no ring before alarm time");
    tick_to(3);
    check(o_alarm_ring == 1, "ring starts at 00:00:03");
    tick_to(4); tick_to(5); tick_to(6); tick_to(7);
    check(o_alarm_ring == 1, "ring keeps after time passes");
    tick_to(8);
    check(o_alarm_ring == 0, "ring auto off after RING_SEC");

    i_clock_min = 1; tick_to(3);
    i_clock_min = 0; tick_to(2); tick_to(3);
    check(o_alarm_ring == 1, "ring again next match");
    pulse_stop;
    check(o_alarm_ring == 0, "stop (PSD) turns ring off");
    repeat(10) @(negedge i_clk);
    check(o_alarm_ring == 0, "no re-ring within same matching second");

    tick_to(2); tick_to(3);
    check(o_alarm_ring == 1, "ring for en-off test");
    pulse_en;
    @(negedge i_clk);
    check(o_alarm_ring == 0 && o_alarm_en == 0, "alarm OFF clears ring");

    if(err == 0) $display("ALL PASS");
    else $display("%0d FAIL", err);
    $finish;
end

endmodule
