module ssegdisp_enabler
(
    output reg [5:0] o_seg_enb,
    input [2:0] i_cnt
);

    always @(*) begin
        case(i_cnt)
            4'd0: o_seg_enb = 6'b111110;
            4'd1: o_seg_enb = 6'b111101;
            4'd2: o_seg_enb = 6'b111011;
            4'd3: o_seg_enb = 6'b110111;
            4'd4: o_seg_enb = 6'b101111;
            4'd5: o_seg_enb = 6'b011111;
            default:o_seg_enb = 6'b111111;
        endcase
    end
    
endmodule
