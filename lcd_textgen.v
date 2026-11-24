`include    "textgen_nco.v"

module  lcd_textgen
#(
    parameter   FREQDIV = 5000000
)
(
    output                  o_line_data_valid,
    output  reg [16*8-1:0]  o_line_data1,
    output  reg [16*8-1:0]  o_line_data2,
    input       [1:0]       i_mode,
    input       [1:0]       i_page,
    input       [4:0]       i_clock_hour,
    input       [5:0]       i_clock_min,
    input       [5:0]       i_clock_sec,
    input       [4:0]       i_alarm_hour,
    input       [5:0]       i_alarm_min,
    input       [5:0]       i_alarm_sec,
    input                   i_alarm_en,
    input       [4:0]       i_timer_hour,
    input       [5:0]       i_timer_min,
    input       [5:0]       i_timer_sec,
    input                   i_timer_run,
    input                   i_clk,
    input                   i_rstn
);
    localparam  MODE_CLOCK      = 2'd0;
    localparam  MODE_CLOCK_SET  = 2'd1;
    localparam  MODE_ALARM_SET  = 2'd2;
    localparam  MODE_TIMER      = 2'd3;

    localparam  PAGE_TIME       = 2'd0;
    localparam  PAGE_ALARM      = 2'd1;
    localparam  PAGE_TIMER      = 2'd2;

    textgen_nco
    #(
        .FREQDIV            (FREQDIV            )
    )
    u_textgen_nco(
        .o_clk              (o_line_data_valid  ),
        .i_clk              (i_clk              ),
        .i_rstn             (i_rstn             )
    );

    function [15:0] dec2;
        input   [6:0]   num;
        reg     [7:0]   ch10;
        reg     [7:0]   ch1;
        begin
            ch10 = 8'h30 + (num / 10);
            ch1  = 8'h30 + (num % 10);
            dec2 = {ch10, ch1};
        end
    endfunction

    wire    [15:0]  str_clk_h   = dec2({2'b00, i_clock_hour});
    wire    [15:0]  str_clk_m   = dec2({1'b0 , i_clock_min });
    wire    [15:0]  str_clk_s   = dec2({1'b0 , i_clock_sec });
    wire    [15:0]  str_alm_h   = dec2({2'b00, i_alarm_hour});
    wire    [15:0]  str_alm_m   = dec2({1'b0 , i_alarm_min });
    wire    [15:0]  str_alm_s   = dec2({1'b0 , i_alarm_sec });
    wire    [15:0]  str_tmr_h   = dec2({2'b00, i_timer_hour});
    wire    [15:0]  str_tmr_m   = dec2({1'b0 , i_timer_min });
    wire    [15:0]  str_tmr_s   = dec2({1'b0 , i_timer_sec });

    always @(*) begin
        case (i_mode)
            MODE_CLOCK      : o_line_data1 = "MODE: CLOCK     ";
            MODE_CLOCK_SET  : o_line_data1 = "MODE: CLOCK SET ";
            MODE_ALARM_SET  : o_line_data1 = "MODE: ALARM SET ";
            MODE_TIMER      : o_line_data1 = "MODE: TIMER     ";
            default         : o_line_data1 = "MODE: ?         ";
        endcase
    end

    always @(*) begin
        case (i_page)
            PAGE_TIME   : o_line_data2 = {"TIME    ", str_clk_h, ":", str_clk_m, ":", str_clk_s};
            PAGE_ALARM  : o_line_data2 = {"ALM ", str_alm_h, ":", str_alm_m, ":", str_alm_s,
                                          (i_alarm_en ? " ON " : " OFF")};
            PAGE_TIMER  : o_line_data2 = {"TMR ", str_tmr_h, ":", str_tmr_m, ":", str_tmr_s,
                                          (i_timer_run ? " RUN" : " STP")};
            default     : o_line_data2 = "                ";
        endcase
    end

endmodule
