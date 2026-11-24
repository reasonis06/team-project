module alarm_cnt
#(
    parameter MAX = 59
)
(
    output reg [$clog2(MAX+1)-1:0] o_cnt,
    input        i_clk,
    input        i_rstn
);

always @(posedge i_clk or negedge i_rstn) begin
    if(!i_rstn) begin
        o_cnt <= 0;
    end else begin
        if(o_cnt == MAX) begin
            o_cnt <= 0;
        end else begin
            o_cnt <= o_cnt + 1;
        end
    end
end

endmodule