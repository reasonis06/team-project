`include "buzzer_nco.v"
`include "buzzer_sheet.v"

module buzzer (
    output      o_out,
    input       i_enb,
    input       i_clk,
    input       i_rstn
);

localparam UPBND = 15;

reg  [$clog2(UPBND+1)-1:0] cnt;
reg  [31:0]                dur_cnt;
wire                       buzz;
wire [31:0]                note;
wire [31:0]                dur;

buzzer_sheet u_buzzer_sheet(
    .o_note (note  ),
    .o_dur  (dur   ),
    .i_cnt  (cnt   )
);

always @(posedge i_clk or negedge i_rstn) begin
    if (!i_rstn) begin
        cnt     <= 6'd0;
        dur_cnt <= 32'd0;
    end else if (i_enb) begin
        cnt     <= 6'd0;
        dur_cnt <= 32'd0;
    end else begin
        if (dur_cnt >= dur - 1) begin
            dur_cnt <= 32'd0;
            if (cnt >= UPBND) begin
                cnt <= 6'd0;
            end else begin
                cnt <= cnt + 6'd1;
            end
        end else begin
            dur_cnt <= dur_cnt + 32'd1;
        end
    end
end

buzzer_nco u_buzzer_buzz(
    .o_clk      (buzz   ),
    .i_freq_div (note   ),
    .i_clk      (i_clk  ),
    .i_rstn     (i_rstn )
);

wire gate_en = (dur_cnt < (dur - (dur >> 3)));

assign o_out = ~i_enb & buzz & gate_en & (note != 32'd1000);

endmodule