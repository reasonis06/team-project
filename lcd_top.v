`include    "textlcd.v"
`include    "lcd_textgen.v"
`include    "lcd_psd_page.v"

module  lcd_top
#(
    parameter   TEXT_FREQDIV    = 5000000,
    parameter   PSD_ACTIVE_LOW  = 0,
    parameter   PSD_STABLE      = 1000000
)
(
    output              o_lcd_e,
    output              o_lcd_rs,
    output              o_lcd_rw,
    inout       [7:0]   io_lcd_data,
    output      [1:0]   o_page,
    output              o_psd_pulse,
    input       [1:0]   i_mode,
    input               i_psd,
    input       [4:0]   i_clock_hour,
    input       [5:0]   i_clock_min,
    input       [5:0]   i_clock_sec,
    input       [4:0]   i_alarm_hour,
    input       [5:0]   i_alarm_min,
    input       [5:0]   i_alarm_sec,
    input               i_alarm_en,
    input       [4:0]   i_timer_hour,
    input       [5:0]   i_timer_min,
    input       [5:0]   i_timer_sec,
    input               i_timer_run,
    input               i_clk,
    input               i_rstn
);
    wire                    line_data_valid;
    wire        [16*8-1:0]  line_data1;
    wire        [16*8-1:0]  line_data2;
    wire        [1:0]       page;

    assign  o_page = page;

    lcd_psd_page
    #(
        .PSD_ACTIVE_LOW     (PSD_ACTIVE_LOW     ),
        .STABLE_CYCLES      (PSD_STABLE         )
    )
    u_lcd_psd_page(
        .o_page             (page               ),
        .o_psd_pulse        (o_psd_pulse        ),
        .i_psd              (i_psd              ),
        .i_mode             (i_mode             ),
        .i_clk              (i_clk              ),
        .i_rstn             (i_rstn             )
    );

    lcd_textgen
    #(
        .FREQDIV            (TEXT_FREQDIV       )
    )
    u_lcd_textgen(
        .o_line_data_valid  (line_data_valid    ),
        .o_line_data1       (line_data1         ),
        .o_line_data2       (line_data2         ),
        .i_mode             (i_mode             ),
        .i_page             (page               ),
        .i_clock_hour       (i_clock_hour       ),
        .i_clock_min        (i_clock_min        ),
        .i_clock_sec        (i_clock_sec        ),
        .i_alarm_hour       (i_alarm_hour       ),
        .i_alarm_min        (i_alarm_min        ),
        .i_alarm_sec        (i_alarm_sec        ),
        .i_alarm_en         (i_alarm_en         ),
        .i_timer_hour       (i_timer_hour       ),
        .i_timer_min        (i_timer_min        ),
        .i_timer_sec        (i_timer_sec        ),
        .i_timer_run        (i_timer_run        ),
        .i_clk              (i_clk              ),
        .i_rstn             (i_rstn             )
    );

    textlcd
    u_textlcd(
        .o_lcd_e            (o_lcd_e            ),
        .o_lcd_rs           (o_lcd_rs           ),
        .o_lcd_rw           (o_lcd_rw           ),
        .io_lcd_data        (io_lcd_data        ),
        .i_line_data1       (line_data1         ),
        .i_line_data2       (line_data2         ),
        .i_line_data_valid  (line_data_valid    ),
        .i_clk              (i_clk              ),
        .i_rstn             (i_rstn             )
    );

endmodule
