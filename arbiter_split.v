module arbiter_split
#(
    parameter MAX = 59
)
(
    output [3:0] o_num_l,
    output [3:0] o_num_r,
    input [$clog2(MAX+1)-1:0] i_num
);

assign o_num_l = i_num / 10;
assign o_num_r = i_num % 10;

endmodule
