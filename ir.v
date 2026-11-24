`include "ir_nco.v"

module ir
#(
    parameter FREQDIV = 50
)
(
    output reg [31:0] o_data,
    output reg o_valid,
    input i_ir_rxb,
    input i_clk,
    input i_rstn
);

localparam LEADCODE = 1'b0;
localparam DATACODE = 1'b1;

wire clk_1M;

ir_nco
#(
    .FREQDIV(FREQDIV)
)
u_ir_nco(
    .o_clk(clk_1M),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

wire ir_rx = ~i_ir_rxb;
reg [1:0] seq_rx;

always @(posedge clk_1M or negedge i_rstn) begin
    if(!i_rstn) begin
        seq_rx <= 2'b00;
    end else begin
        seq_rx <= {seq_rx[0], ir_rx};
    end
end

reg [15:0] cnt_h;
reg [15:0] cnt_l;

always @(posedge clk_1M or negedge i_rstn) begin
    if(!i_rstn) begin
        cnt_h <= 16'd0;
        cnt_l <= 16'd0;
    end else begin
        case(seq_rx)
            2'b00: begin
                cnt_l <= (cnt_l == 16'hFFFF) ? cnt_l : cnt_l + 16'd1;
                cnt_h <= cnt_h;
            end
            2'b01: begin
                cnt_l <= 16'd0;
                cnt_h <= 16'd0;
            end
            2'b11: begin
                cnt_l <= cnt_l;
                cnt_h <= (cnt_h == 16'hFFFF) ? cnt_h : cnt_h + 16'd1;
            end
            default: begin
                cnt_l <= cnt_l;
                cnt_h <= cnt_h;
            end
        endcase
    end
end

reg c_state;
reg n_state;
reg [4:0] cnt;

always @(posedge clk_1M or negedge i_rstn) begin
    if(!i_rstn) begin
        c_state <= LEADCODE;
    end else begin
        if(seq_rx == 2'b01) begin
            c_state <= n_state;
        end else begin
            c_state <= c_state;
        end
    end
end

always @(posedge clk_1M or negedge i_rstn) begin
    if(!i_rstn) begin
        cnt <= 5'd0;
    end else begin
        if(c_state == LEADCODE) begin
            cnt <= 5'd0;
        end else if(seq_rx == 2'b01) begin
            cnt <= cnt + 5'd1;
        end else begin
            cnt <= cnt;
        end
    end
end

always @(*) begin
    case(c_state)
        LEADCODE: begin
            if(cnt_h >= 16'd8000 && cnt_l >= 16'd3500) begin
                n_state = DATACODE;
            end else begin
                n_state = LEADCODE;
            end
        end
        DATACODE: begin
            if(cnt == 5'd31) begin
                n_state = LEADCODE;
            end else begin
                n_state = DATACODE;
            end
        end
        default: n_state = LEADCODE;
    endcase
end

wire rx_bit = (c_state == DATACODE) && (cnt_l >= 16'd1000);

always @(posedge clk_1M or negedge i_rstn) begin
    if(!i_rstn) begin
        o_data <= 32'd0;
        o_valid <= 1'b0;
    end else begin
        if(c_state == DATACODE && seq_rx == 2'b01) begin
            o_data <= {o_data[30:0], rx_bit};
        end else begin
            o_data <= o_data;
        end
        o_valid <= (c_state == DATACODE) && (seq_rx == 2'b01) && (cnt == 5'd31);
    end
end

endmodule
