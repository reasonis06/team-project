module clock_cnt
#(
    parameter MAX = 59
)
(
    output reg [$clog2(MAX+1)-1:0] o_cnt,
    output reg o_max,
    input i_clk,
    input i_down,
    input i_rstn
);

always @(posedge i_clk or negedge i_rstn) begin
    if(!i_rstn) begin
        o_cnt <= MAX;
        o_max <= 0;
    end else begin
        if(i_down) begin
            if (o_cnt == 0) begin
                o_cnt <= MAX;
            end else begin
                o_cnt <= o_cnt -1;
            end
            o_max <= 0;

        end else begin
            if(o_cnt == MAX) begin
                o_cnt <= 0;
                o_max <= 1;
            end else begin
                o_cnt <= o_cnt + 1;
                o_max <= 0;
            end
                
        end
    end
end

endmodule