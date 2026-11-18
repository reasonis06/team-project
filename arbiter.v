`include "arbiter_split.v"

module arbiter
(
    output [3:0] o_num0,
    output [3:0] o_num1,
    output [3:0] o_num2,
    output [3:0] o_num3,
    output [3:0] o_num4,
    output [3:0] o_num5,
    input i_mode,
    input [5:0] i_clock_sec,
    input [5:0] i_clock_min,
    input [5:0] i_clock_hour,
    input [5:0] i_undef_sec,
    input [5:0] i_undef_min,
    input [5:0] i_undef_hour
);

localparam MODE_CLOCK_OPR = 1'b0;
localparam MODE_CLOCK_SET = 1'b1;

// MUX
reg [5:0] sec;
reg [5:0] min;
reg [5:0] hour;

always @(*) begin
    case (i_mode)
        MODE_CLOCK_OPR,
        MODE_CLOCK_SET: begin
            sec = i_clock_sec;
            min = i_clock_min;
            hour = i_clock_hour;
        end
        default: begin
            sec = i_undef_sec;
            min = i_undef_min;
            hour = i_undef_hour;
        end
    endcase
end

// Number Split
arbiter_split
#(
    .MAX(59)
)
u_arbiter_split_sec(
    .o_num_l(o_num1),
    .o_num_r(o_num0),
    .i_num(sec)
);

arbiter_split
#(
    .MAX(59)
)
u_arbiter_split_min(
    .o_num_l(o_num3),
    .o_num_r(o_num2),
    .i_num(min)
);

arbiter_split
#(
    .MAX(23)
)
u_arbiter_split_hour(
    .o_num_l(o_num5),
    .o_num_r(o_num4),
    .i_num(hour)
);

endmodule
