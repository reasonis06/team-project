module psd_detect
#(
    parameter TH_ON = 12'd1800,
    parameter TH_OFF = 12'd1300
)
(
    output reg o_near,
    input [11:0] i_data,
    input i_clk,
    input i_rstn
);

reg [11:0] data_s;

always @(posedge i_clk or negedge i_rstn) begin
    if(!i_rstn) begin
        data_s <= 12'd0;
        o_near <= 1'b0;
    end else begin
        data_s <= i_data;
        if(!o_near && data_s >= TH_ON) begin
            o_near <= 1'b1;
        end else if(o_near && data_s <= TH_OFF) begin
            o_near <= 1'b0;
        end else begin
            o_near <= o_near;
        end
    end
end

endmodule
