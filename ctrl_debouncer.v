`include "ctrl_nco.v"

module ctrl_debouncer
#(
    parameter FREQDIV = 5000000
)
(
    output [7:0] o_sw,
    input [7:0] i_sw,
    input i_clk,
    input i_rstn
);

wire slow_clk;

ctrl_nco
#(
    .FREQDIV(FREQDIV)
)
u_debouncer_nco(
    .o_clk(slow_clk),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

reg [7:0] n1;
reg [7:0] n2;

always @(posedge slow_clk) begin
    n1 <= i_sw;
    n2 <= n1;
end

assign o_sw = n1 | ~n2;

endmodule