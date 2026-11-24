`include "psd_nco.v"

module psd
#(
    parameter FREQDIV = 4
)
(
    output o_sclk,
    output reg o_csn,
    output reg o_din,
    output reg [11:0] o_data,
    input i_dout,
    input [2:0] i_addr,
    input i_clk,
    input i_rstn
);

psd_nco
#(
    .FREQDIV(FREQDIV)
)
u_psd_nco(
    .o_clk(o_sclk),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

reg [3:0] cnt;
reg [11:0] data;

always @(posedge o_sclk or negedge i_rstn) begin
    if(!i_rstn) begin
        cnt <= 4'd15;
        o_csn <= 1'b1;
    end else begin
        cnt <= cnt + 4'd1;
        o_csn <= 1'b0;
    end
end

always @(*) begin
    case(cnt)
        4'd2: o_din = i_addr[2];
        4'd3: o_din = i_addr[1];
        4'd4: o_din = i_addr[0];
        default: o_din = 1'b0;
    endcase
end

always @(posedge o_sclk or negedge i_rstn) begin
    if(!i_rstn) begin
        data <= 12'd0;
        o_data <= 12'd0;
    end else begin
        data <= {data[10:0], i_dout};
        if(cnt == 4'd15) begin
            o_data <= {data[10:0], i_dout};
        end else begin
            o_data <= o_data;
        end
    end
end

endmodule
