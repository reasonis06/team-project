module buzzer_nco
(
    output reg      o_clk,
    input [31:0]    i_freq_div,
    input           i_clk,
    input           i_rstn
);

reg [31:0] cnt;

always @(posedge i_clk or negedge i_rstn) begin
    if(!i_rstn) begin
        cnt   <= (2**32) - 1;
        o_clk <= 0;
    end else begin
        if(cnt >= i_freq_div/2 - 1) begin
            cnt   <= 0;
            o_clk <= ~o_clk;
        end else begin
            cnt   <= cnt + 1;
            o_clk <= o_clk;
        end
    end
end

endmodule