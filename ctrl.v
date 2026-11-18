`include "ctrl_debouncer.v"

module ctrl
(
    output reg o_mode,
    output reg o_hour_clk,
    output reg o_min_clk,
    output reg o_sec_clk,
    output reg o_down,
    output [1:0] o_targ,
    output o_blink,
    input i_hour_max,
    input i_min_max,
    input i_sec_max,
    input [7:0] i_sw,
    input i_clk,
    input i_rstn
);

wire clk_1hz;
wire [7:0] sw;

ctrl_debouncer
#(
    .FREQDIV(5000000)
)
u_ctrl_debouncer(
    .o_sw(sw),
    .i_sw(i_sw),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

ctrl_nco
#(
    .FREQDIV(50000000)
)
u_ctrl_nco(
    .o_clk(clk_1hz),
    .i_clk(i_clk),
    .i_rstn(i_rstn)
);

reg c_mode;
reg n_mode;
reg [1:0] c_targ;
reg [1:0] n_targ;

localparam MODE_CLOCK_OPR = 1'b0;
localparam MODE_CLOCK_SET = 1'b1;
localparam TARG_SEC  = 2'd0;
localparam TARG_MIN  = 2'd1;
localparam TARG_HOUR = 2'd2;

assign o_targ = c_targ;
assign o_blink = (c_mode == MODE_CLOCK_SET) && clk_1hz;


reg up_prev;
reg down_prev;
reg set_down;
reg set_clk;

always @(posedge i_clk or negedge i_rstn) begin
    if(!i_rstn) begin
        up_prev <= 1'b1;
        down_prev <= 1'b1;
        set_down <= 1'b0;
        set_clk <= 1'b0;
    end else begin
        up_prev <= sw[2];
        down_prev <= sw[3];

        set_clk <= 1'b0;

        if(c_mode == MODE_CLOCK_SET) begin
            if(up_prev && !sw[2] && sw[3]) begin
                set_down <= 1'b0;
                set_clk <= 1'b1;
            end else if(down_prev && !sw[3] && sw[2]) begin
                set_down <= 1'b1;
                set_clk <= 1'b1;
            end
        end
    end
end


// State Register
always @(posedge sw[0] or negedge i_rstn) begin
    if(!i_rstn) begin
        c_mode <= MODE_CLOCK_OPR;
    end else begin
        c_mode <= n_mode;
    end
end

always @(posedge sw[1] or negedge i_rstn) begin
    if(!i_rstn) begin
        c_targ <= TARG_SEC;
    end else begin
        c_targ <= n_targ;
    end
end

// 'Next Mode' Comb. Logic
always @(*) begin
    case(c_mode)
        MODE_CLOCK_OPR: n_mode = MODE_CLOCK_SET;
        MODE_CLOCK_SET: n_mode = MODE_CLOCK_OPR;
    endcase
end

// 'Next Target' Comb. Logic
always @(*) begin
    case(c_targ)
    TARG_SEC:  n_targ = TARG_MIN;
    TARG_MIN:  n_targ = TARG_HOUR;
    TARG_HOUR: n_targ = TARG_SEC;
    endcase
end

// 'Output' Comb. Logic
always @(*) begin
    case(c_mode)
        MODE_CLOCK_OPR: begin
            o_mode = MODE_CLOCK_OPR;
            o_down = 1'b0;
            o_sec_clk = clk_1hz;
            o_min_clk = i_sec_max;
            o_hour_clk = i_min_max;
        end
        MODE_CLOCK_SET: begin
            o_mode = MODE_CLOCK_SET;
            o_down = set_down;
            case(c_targ)
                TARG_SEC: begin
                    o_sec_clk = set_clk;
                    o_min_clk = 1'b0;
                    o_hour_clk = 1'b0;
                end
                TARG_MIN: begin
                    o_sec_clk = 1'b0;
                    o_min_clk = set_clk;
                    o_hour_clk = 1'b0;
                end
                 TARG_HOUR: begin
                    o_sec_clk = 1'b0;
                    o_min_clk = 1'b0;
                    o_hour_clk = set_clk;
                end
            endcase
        end
    endcase
end

endmodule
