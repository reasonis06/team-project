module  lcd_psd_page
#(
    parameter   PSD_ACTIVE_LOW  = 0,
    parameter   STABLE_CYCLES   = 1000000
)
(
    output  reg [1:0]   o_page,
    output              o_psd_pulse,
    input               i_psd,
    input       [1:0]   i_mode,
    input               i_clk,
    input               i_rstn
);
    localparam  PAGE_TIME       = 2'd0;
    localparam  PAGE_ALARM      = 2'd1;
    localparam  PAGE_TIMER      = 2'd2;

    localparam  MODE_CLOCK      = 2'd0;
    localparam  MODE_CLOCK_SET  = 2'd1;
    localparam  MODE_ALARM_SET  = 2'd2;
    localparam  MODE_TIMER      = 2'd3;

    reg         [1:0]   psd_sync;
    reg         [1:0]   mode_s1;
    reg         [1:0]   mode_s2;

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            psd_sync    <= 2'b00;
            mode_s1     <= MODE_CLOCK;
            mode_s2     <= MODE_CLOCK;
        end else begin
            psd_sync    <= {psd_sync[0], i_psd ^ PSD_ACTIVE_LOW[0]};
            mode_s1     <= i_mode;
            mode_s2     <= mode_s1;
        end
    end

    wire    psd_raw = psd_sync[1];

    localparam  CNT_W = (STABLE_CYCLES > 1) ? $clog2(STABLE_CYCLES) : 1;

    reg     [CNT_W-1:0] stable_cnt;
    reg                 psd_near;
    reg                 psd_near_d;

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            stable_cnt  <= 0;
            psd_near    <= 1'b0;
            psd_near_d  <= 1'b0;
        end else begin
            psd_near_d  <= psd_near;
            if (psd_raw == psd_near) begin
                stable_cnt  <= 0;
            end else if (stable_cnt >= STABLE_CYCLES - 1) begin
                stable_cnt  <= 0;
                psd_near    <= psd_raw;
            end else begin
                stable_cnt  <= stable_cnt + 1;
            end
        end
    end

    assign  o_psd_pulse = psd_near & ~psd_near_d;

    reg         [1:0]   mode_d;
    wire                mode_changed = (mode_s2 != mode_d);

    reg         [1:0]   mode_page;
    always @(*) begin
        case (mode_s2)
            MODE_ALARM_SET  : mode_page = PAGE_ALARM;
            MODE_TIMER      : mode_page = PAGE_TIMER;
            default         : mode_page = PAGE_TIME;
        endcase
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            mode_d  <= MODE_CLOCK;
            o_page  <= PAGE_TIME;
        end else begin
            mode_d  <= mode_s2;
            if (mode_changed) begin
                o_page  <= mode_page;
            end else if (o_psd_pulse) begin
                case (o_page)
                    PAGE_TIME   : o_page <= PAGE_ALARM;
                    PAGE_ALARM  : o_page <= PAGE_TIMER;
                    default     : o_page <= PAGE_TIME;
                endcase
            end
        end
    end

endmodule
