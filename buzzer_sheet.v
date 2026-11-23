module buzzer_sheet
(
    output reg [31:0] o_note, // 음의 높이
    output reg [31:0] o_dur,  // 음의 길이 <<new!
    input      [5:0]  i_cnt
);

// 음의 높이 정의
localparam C5   = 95556;
localparam D5   = 85132;
localparam DS5  = 80353;
localparam E5   = 75844;
localparam F5   = 71586;
localparam FS5  = 67569;
localparam G5   = 63776;
localparam A5   = 56818;
localparam B5   = 50620;

localparam C4   = C5*2;
localparam D4   = D5*2;
localparam E4   = E5*2;
localparam F4   = F5*2;
localparam G4   = G5*2;
localparam A4   = A5*2;
localparam B4   = B5*2;

localparam REST = 1000;

// 음의 길이 정의 << new!
localparam DH_NOTE = 32'd75000000; // 점2분음표
localparam H_NOTE  = 32'd50000000; // 2분음표
localparam Q_NOTE  = 32'd25000000; // 4분음표
localparam DQ_NOTE = 32'd37500000; // 점4분음표
localparam E_NOTE  = 32'd12500000; // 8분음표
localparam DE_NOTE = 32'd18750000; // 점8분음표
localparam S_NOTE  = 32'd6250000;  // 16분음표
localparam T_NOTE  = 32'd8333333;  // 8분 셋잇단음표

always @(*) begin
    case(i_cnt)
        6'd00: begin o_note = B4;   o_dur = Q_NOTE;  end
        6'd01: begin o_note = E5;   o_dur = DQ_NOTE; end
        6'd02: begin o_note = G5;   o_dur = E_NOTE;  end
        6'd03: begin o_note = FS5;  o_dur = Q_NOTE;  end
        6'd04: begin o_note = E5;   o_dur = H_NOTE;  end
        6'd05: begin o_note = B5;   o_dur = Q_NOTE;  end
        6'd06: begin o_note = A5;   o_dur = DH_NOTE; end
        6'd07: begin o_note = FS5;  o_dur = DH_NOTE; end
        6'd08: begin o_note = E5;   o_dur = DQ_NOTE; end
        6'd09: begin o_note = G5;   o_dur = E_NOTE;  end
        6'd10: begin o_note = FS5;  o_dur = Q_NOTE;  end
        6'd11: begin o_note = DS5;  o_dur = H_NOTE;  end
        6'd12: begin o_note = G5;   o_dur = Q_NOTE;  end
        6'd13: begin o_note = B4;   o_dur = DH_NOTE; end
        6'd14: begin o_note = B4;   o_dur = H_NOTE;  end
        6'd15: begin o_note = B4;   o_dur = Q_NOTE;  end
        default: begin o_note = REST; o_dur = E_NOTE; end
    endcase
end

endmodule