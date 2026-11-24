module ssegdisp_dec
(
    output reg [7:0] o_seg,
    input [3:0] i_num,
    input i_dp
);

    always @(*) begin
        case(i_num)
            4'h0: o_seg = {7'b111_1110, i_dp};
            4'h1: o_seg = {7'b011_0000, i_dp};
            4'h2: o_seg = {7'b110_1101, i_dp};
            4'h3: o_seg = {7'b111_1001, i_dp};
            4'h4: o_seg = {7'b011_0011, i_dp};
            4'h5: o_seg = {7'b101_1011, i_dp};
            4'h6: o_seg = {7'b101_1111, i_dp};
            4'h7: o_seg = {7'b111_0000, i_dp};
            4'h8: o_seg = {7'b111_1111, i_dp};
            4'h9: o_seg = {7'b111_0011, i_dp};
            4'ha: o_seg = {7'b111_0111, i_dp};
            4'hb: o_seg = {7'b001_1111, i_dp};
            4'hc: o_seg = {7'b100_1110, i_dp};
            4'hd: o_seg = {7'b011_1101, i_dp};
            4'he: o_seg = {7'b100_1111, i_dp};
            4'hf: o_seg = {7'b100_0111, i_dp};
            default:o_seg = {7'b000_0000, i_dp};
        endcase
    end
    
endmodule