`include "ctrl.v"
`include "clock.v"
`include "alarm.v"
`include "arbiter.v"
`include "buzzer.v"
`include "ssegdisp.v"

module top
(
    output       o_buzzer,
    output [5:0] o_seg_enb,
    output [7:0] o_seg,
    input  [7:0] i_sw,
    input        i_clk,
    input        i_rstn
);

wire [1:0] mode;

wire       clock_min_clk;
wire       clock_sec_clk;
wire       clock_min_max;
wire       clock_sec_max;
wire [5:0] clock_min;
wire [5:0] clock_sec;

wire       alarm_en;
wire       alarm_min_clk;
wire       alarm_sec_clk;
wire [5:0] alarm_min;
wire [5:0] alarm_sec;

wire       buzzer_enb;

wire [3:0] disp_num[0:5];

ctrl
u_ctrl(
    .o_alarm_en      (alarm_en      ),
    .o_mode          (mode          ),
    .o_alarm_min_clk (alarm_min_clk ),
    .o_alarm_sec_clk (alarm_sec_clk ),
    .o_clock_min_clk (clock_min_clk ),
    .o_clock_sec_clk (clock_sec_clk ),
    .i_clock_min_max (clock_min_max ),
    .i_clock_sec_max (clock_sec_max ),
    .i_sw            (i_sw          ),
    .i_clk           (i_clk         ),
    .i_rstn          (i_rstn        )
);

clock
u_clock(
    .o_min     (clock_min     ),
    .o_sec     (clock_sec     ),
    .o_min_max (clock_min_max ),
    .o_sec_max (clock_sec_max ),
    .i_min_clk (clock_min_clk ),
    .i_sec_clk (clock_sec_clk ),
    .i_rstn    (i_rstn        )
);

alarm
u_alarm(
    .o_min     (alarm_min     ),
    .o_sec     (alarm_sec     ),
    .i_min_clk (alarm_min_clk ),
    .i_sec_clk (alarm_sec_clk ),
    .i_rstn    (i_rstn        )
);

arbiter
u_arbiter(
    .o_buzzer_enb (buzzer_enb ),
    .o_num0       (disp_num[0]),
    .o_num1       (disp_num[1]),
    .o_num2       (disp_num[2]),
    .o_num3       (disp_num[3]),
    .o_num4       (disp_num[4]),
    .o_num5       (disp_num[5]),
    .i_mode       (mode       ),
    .i_alarm_en   (alarm_en   ),
    .i_clock_sec  (clock_sec  ),
    .i_clock_min  (clock_min  ),
    .i_alarm_sec  (alarm_sec  ),
    .i_alarm_min  (alarm_min  ),
    .i_undef_sec  (6'd99      ),
    .i_undef_min  (6'd99      ),
    .i_clk        (i_clk      ),
    .i_rstn       (i_rstn     )
);

buzzer
u_buzzer(
    .o_out  (o_buzzer  ),
    .i_enb  (buzzer_enb),
    .i_clk  (i_clk     ),
    .i_rstn (i_rstn    )
);

ssegdisp
#(
    .FREQDIV (5000)
)
u_ssegdisp(
    .o_seg_enb (o_seg_enb  ),
    .o_seg     (o_seg      ),
    .i_num0    (disp_num[0]),
    .i_num1    (disp_num[1]),
    .i_num2    (disp_num[2]),
    .i_num3    (disp_num[3]),
    .i_num4    (disp_num[4]),
    .i_num5    (disp_num[5]),
    .i_dp0     (1'b0       ),
    .i_dp1     (1'b0       ),
    .i_dp2     (1'b1       ),
    .i_dp3     (1'b0       ),
    .i_dp4     (1'b0       ),
    .i_dp5     (1'b0       ),
    .i_clk     (i_clk      ),
    .i_rstn    (i_rstn     )
);

endmodule