`include    "lcd_top.v"

module  lcd_psd_demo_top
#(
    parameter   PSD_ACTIVE_LOW  = 0,
    parameter   SEC_FREQDIV     = 50000000,
    parameter   BTN_FREQDIV     = 500000,
    parameter   TEXT_FREQDIV    = 5000000,
    parameter   PSD_STABLE      = 1000000
)
(
    output              o_lcd_e,
    output              o_lcd_rs,
    output              o_lcd_rw,
    inout       [7:0]   io_lcd_data,
    input               i_psd,
    input               i_btn_psd,
    input               i_btn_mode,
    input               i_clk,
    input               i_rstn
);
    reg     [$clog2(SEC_FREQDIV)-1:0]   sec_cnt;
    reg     [$clog2(BTN_FREQDIV)-1:0]   btn_cnt;
    wire    tick_1hz = (sec_cnt == SEC_FREQDIV - 1);
    wire    tick_btn = (btn_cnt == BTN_FREQDIV - 1);

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            sec_cnt <= 0;
            btn_cnt <= 0;
        end else begin
            sec_cnt <= tick_1hz ? 0 : sec_cnt + 1;
            btn_cnt <= tick_btn ? 0 : btn_cnt + 1;
        end
    end

    reg     [1:0]   btn_mode_s;
    reg     [1:0]   mode;

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            btn_mode_s  <= 2'b11;
            mode        <= 2'd0;
        end else if (tick_btn) begin
            btn_mode_s  <= {btn_mode_s[0], i_btn_mode};
            if (btn_mode_s == 2'b10)
                mode    <= mode + 1;
        end
    end

    reg     [4:0]   clk_h;
    reg     [5:0]   clk_m;
    reg     [5:0]   clk_s;

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            clk_h <= 5'd12; clk_m <= 6'd0; clk_s <= 6'd0;
        end else if (tick_1hz) begin
            if (clk_s == 6'd59) begin
                clk_s <= 6'd0;
                if (clk_m == 6'd59) begin
                    clk_m <= 6'd0;
                    clk_h <= (clk_h == 5'd23) ? 5'd0 : clk_h + 1;
                end else begin
                    clk_m <= clk_m + 1;
                end
            end else begin
                clk_s <= clk_s + 1;
            end
        end
    end

    reg     [5:0]   tmr_m;
    reg     [5:0]   tmr_s;
    wire            tmr_run = (tmr_m != 6'd0) || (tmr_s != 6'd0);

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            tmr_m <= 6'd3;  tmr_s <= 6'd0;
        end else if (tick_1hz && tmr_run) begin
            if (tmr_s == 6'd0) begin
                tmr_s <= 6'd59;
                tmr_m <= tmr_m - 1;
            end else begin
                tmr_s <= tmr_s - 1;
            end
        end
    end

    wire    psd_near = (i_psd ^ PSD_ACTIVE_LOW[0]) | ~i_btn_psd;

    lcd_top
    #(
        .TEXT_FREQDIV       (TEXT_FREQDIV       ),
        .PSD_ACTIVE_LOW     (0                  ),
        .PSD_STABLE         (PSD_STABLE         )
    )
    u_lcd_top(
        .o_lcd_e            (o_lcd_e            ),
        .o_lcd_rs           (o_lcd_rs           ),
        .o_lcd_rw           (o_lcd_rw           ),
        .io_lcd_data        (io_lcd_data        ),
        .o_page             (                   ),
        .i_mode             (mode               ),
        .i_psd              (psd_near           ),
        .i_clock_hour       (clk_h              ),
        .i_clock_min        (clk_m              ),
        .i_clock_sec        (clk_s              ),
        .i_alarm_hour       (5'd7               ),
        .i_alarm_min        (6'd30              ),
        .i_alarm_sec        (6'd0               ),
        .i_alarm_en         (1'b1               ),
        .i_timer_hour       (5'd0               ),
        .i_timer_min        (tmr_m              ),
        .i_timer_sec        (tmr_s              ),
        .i_timer_run        (tmr_run            ),
        .i_clk              (i_clk              ),
        .i_rstn             (i_rstn             )
    );

endmodule
