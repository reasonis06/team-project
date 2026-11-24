`include    "textlcd_nco.v"

module  textlcd
(
    output reg              o_lcd_e,
    output reg              o_lcd_rs,
    output reg              o_lcd_rw,
    inout       [7:0]       io_lcd_data,
    input       [16*8-1:0]  i_line_data1,
    input       [16*8-1:0]  i_line_data2,
    input                   i_line_data_valid,
    input                   i_clk,
    input                   i_rstn
);
    reg     [7:0]   lcd_data;
    assign          io_lcd_data = o_lcd_rw ? 8'hzz : lcd_data;

    wire            clk_nco;

    textlcd_nco
    #(
        .FREQDIV    (50         )
    )
    u_textlcd_nco(
        .o_clk      (clk_nco    ),
        .i_clk      (i_clk      ),
        .i_rstn     (i_rstn     )
    );

    reg     [1:0]   cnt_timing;
    reg             clk_ref;

    always @(posedge clk_nco or negedge i_rstn) begin
        if (!i_rstn) begin
            cnt_timing  <= 2'd3;
        end else begin
            cnt_timing  <= cnt_timing + 1;
        end
    end

    always @(posedge clk_nco or negedge i_rstn) begin
        if (!i_rstn) begin
            clk_ref <= 1'b0;
        end else begin
            if (cnt_timing == 2'd3) begin
                clk_ref <= 1'b1;
            end else begin
                clk_ref <= 1'b0;
            end
        end
    end

    always @(*) begin
        if (^cnt_timing) begin
            o_lcd_e     = 1'b1;
        end else begin
            o_lcd_e     = 1'b0;
        end
    end

    reg     [16*8-1:0]  line_data1;
    reg     [16*8-1:0]  line_data2;
    reg     [1:0]       line_data_valid_seq;
    wire                line_data_valid;

    always @(posedge clk_ref or negedge i_rstn) begin
        if (!i_rstn) begin
            line_data_valid_seq <= 2'b00;
        end else begin
            line_data_valid_seq <= {line_data_valid_seq[0], i_line_data_valid};
        end
    end

    assign  line_data_valid = (line_data_valid_seq == 2'b01) ? 1'b1 : 1'b0;

    always @(posedge clk_ref or negedge i_rstn) begin
        if (!i_rstn) begin
            line_data1      <= 128'd0;
            line_data2      <= 128'd0;
        end else begin
            if (line_data_valid) begin
                line_data1  <= i_line_data1;
                line_data2  <= i_line_data2;
            end else begin
                line_data1  <= line_data1;
                line_data2  <= line_data2;
            end
        end
    end

    localparam  LCD_BUSY_CHECK  = 10'b01_zzzz_zzzz;
    localparam  LCD_RETURN_HOME = 10'b00_0000_0010;
    localparam  LCD_FUNC_SET    = 10'b00_0011_1100;
    localparam  LCD_DISP_ONOFF  = 10'b00_0000_1100;
    localparam  LCD_DISP_CLEAR  = 10'b00_0000_0001;
    localparam  LCD_ENTR_SET    = 10'b00_0000_0110;
    localparam  LCD_DDRAM_ADDR1 = 10'b00_1000_0000;
    localparam  LCD_DDRAM_ADDR2 = 10'b00_1100_0000;
    localparam  LCD_DDRAM_WDATA = 2'b10;

    localparam  FSM_BUSY_CHECK  = 4'd0;
    localparam  FSM_RETURN_HOME = 4'd1;
    localparam  FSM_FUNC_SET    = 4'd2;
    localparam  FSM_DISP_ONOFF  = 4'd3;
    localparam  FSM_DISP_CLEAR  = 4'd4;
    localparam  FSM_ENTR_SET    = 4'd5;
    localparam  FSM_LINE1_ADDR  = 4'd6;
    localparam  FSM_LINE1_DATA  = 4'd7;
    localparam  FSM_LINE2_ADDR  = 4'd8;
    localparam  FSM_LINE2_DATA  = 4'd9;

    reg     [3:0]   c_state;
    reg     [3:0]   n_state;
    reg     [3:0]   p_state;

    reg             busy_flag;

    always @(posedge clk_nco or negedge i_rstn) begin
        if (!i_rstn) begin
            busy_flag   <= 1'b0;
        end else begin
            if (c_state == FSM_BUSY_CHECK && cnt_timing == 2) begin
                busy_flag   <= io_lcd_data[7];
            end else begin
                busy_flag   <= busy_flag;
            end
        end
    end

    reg     [3:0]   cnt_char;

    always @(posedge clk_ref or negedge i_rstn) begin
        if (!i_rstn) begin
            cnt_char    <= 4'b0;
        end else begin
            if (c_state == FSM_LINE1_DATA || c_state == FSM_LINE2_DATA) begin
                cnt_char    <= cnt_char + 1;
            end else begin
                cnt_char    <= cnt_char;
            end
        end
    end

    reg             init_done;

    always @(posedge clk_ref or negedge i_rstn) begin
        if (!i_rstn) begin
            init_done   <= 1'b0;
        end else begin
            if (c_state == FSM_ENTR_SET) begin
                init_done   <= 1'b1;
            end else begin
                init_done   <= init_done;
            end
        end
    end

    always @(posedge clk_ref or negedge i_rstn) begin
        if (!i_rstn) begin
            c_state <= FSM_RETURN_HOME;
        end else begin
            if (busy_flag) begin
                c_state <= FSM_BUSY_CHECK;
            end else begin
                c_state <= n_state;
            end
        end
    end

    always @(posedge clk_ref or negedge i_rstn) begin
        if (!i_rstn) begin
            p_state <= FSM_RETURN_HOME;
        end else begin
            if (c_state != FSM_BUSY_CHECK) begin
                p_state <= c_state;
            end else begin
                p_state <= p_state;
            end
        end
    end

    always @(*) begin
        case (c_state)
            FSM_RETURN_HOME : n_state = line_data_valid ? FSM_BUSY_CHECK : FSM_RETURN_HOME;
            FSM_BUSY_CHECK  : begin
                case (p_state)
                    FSM_RETURN_HOME : n_state = init_done ? FSM_LINE1_ADDR : FSM_DISP_CLEAR;
                    FSM_DISP_CLEAR  : n_state = FSM_FUNC_SET;
                    FSM_FUNC_SET    : n_state = FSM_DISP_ONOFF;
                    FSM_DISP_ONOFF  : n_state = FSM_ENTR_SET;
                    FSM_ENTR_SET    : n_state = FSM_LINE1_ADDR;
                    FSM_LINE1_ADDR  : n_state = FSM_LINE1_DATA;
                    FSM_LINE2_ADDR  : n_state = FSM_LINE2_DATA;
                    FSM_LINE1_DATA  : n_state = (cnt_char == 0) ? FSM_LINE2_ADDR  : FSM_LINE1_DATA;
                    FSM_LINE2_DATA  : n_state = (cnt_char == 0) ? FSM_RETURN_HOME : FSM_LINE2_DATA;
                    default         : n_state = FSM_RETURN_HOME;
                endcase
            end
            default         : n_state = FSM_BUSY_CHECK;
        endcase
    end

    always @(*) begin
        case (c_state)
            FSM_BUSY_CHECK  :   {o_lcd_rs, o_lcd_rw, lcd_data}  = LCD_BUSY_CHECK;
            FSM_RETURN_HOME :   {o_lcd_rs, o_lcd_rw, lcd_data}  = LCD_RETURN_HOME;
            FSM_FUNC_SET    :   {o_lcd_rs, o_lcd_rw, lcd_data}  = LCD_FUNC_SET;
            FSM_DISP_ONOFF  :   {o_lcd_rs, o_lcd_rw, lcd_data}  = LCD_DISP_ONOFF;
            FSM_DISP_CLEAR  :   {o_lcd_rs, o_lcd_rw, lcd_data}  = LCD_DISP_CLEAR;
            FSM_ENTR_SET    :   {o_lcd_rs, o_lcd_rw, lcd_data}  = LCD_ENTR_SET;
            FSM_LINE1_ADDR  :   {o_lcd_rs, o_lcd_rw, lcd_data}  = LCD_DDRAM_ADDR1;
            FSM_LINE2_ADDR  :   {o_lcd_rs, o_lcd_rw, lcd_data}  = LCD_DDRAM_ADDR2;
            FSM_LINE1_DATA  :   {o_lcd_rs, o_lcd_rw, lcd_data}  = {LCD_DDRAM_WDATA, line_data1[16*8-cnt_char*8-1 -: 8]};
            FSM_LINE2_DATA  :   {o_lcd_rs, o_lcd_rw, lcd_data}  = {LCD_DDRAM_WDATA, line_data2[16*8-cnt_char*8-1 -: 8]};
            default         :   {o_lcd_rs, o_lcd_rw, lcd_data}  = LCD_BUSY_CHECK;
        endcase
    end

    `ifdef DEBUG
        reg     [8*16-1:0]  DEBUG_CSTATE;
        reg     [8*16-1:0]  DEBUG_PSTATE;

        always @(*) begin
            case (c_state)
                FSM_BUSY_CHECK  : DEBUG_CSTATE = "BUSY_CHECK";
                FSM_RETURN_HOME : DEBUG_CSTATE = "RETURN_HOME";
                FSM_FUNC_SET    : DEBUG_CSTATE = "FUNC_SET";
                FSM_DISP_ONOFF  : DEBUG_CSTATE = "DISP_ONOFF";
                FSM_DISP_CLEAR  : DEBUG_CSTATE = "DISP_CLEAR";
                FSM_ENTR_SET    : DEBUG_CSTATE = "ENTR_SET";
                FSM_LINE1_ADDR  : DEBUG_CSTATE = "LINE1_ADDR";
                FSM_LINE1_DATA  : DEBUG_CSTATE = "LINE1_DATA";
                FSM_LINE2_ADDR  : DEBUG_CSTATE = "LINE2_ADDR";
                FSM_LINE2_DATA  : DEBUG_CSTATE = "LINE2_DATA";
                default         : DEBUG_CSTATE = "UNKNOWN";
            endcase
        end

        always @(*) begin
            case (p_state)
                FSM_BUSY_CHECK  : DEBUG_PSTATE = "BUSY_CHECK";
                FSM_RETURN_HOME : DEBUG_PSTATE = "RETURN_HOME";
                FSM_FUNC_SET    : DEBUG_PSTATE = "FUNC_SET";
                FSM_DISP_ONOFF  : DEBUG_PSTATE = "DISP_ONOFF";
                FSM_DISP_CLEAR  : DEBUG_PSTATE = "DISP_CLEAR";
                FSM_ENTR_SET    : DEBUG_PSTATE = "ENTR_SET";
                FSM_LINE1_ADDR  : DEBUG_PSTATE = "LINE1_ADDR";
                FSM_LINE1_DATA  : DEBUG_PSTATE = "LINE1_DATA";
                FSM_LINE2_ADDR  : DEBUG_PSTATE = "LINE2_ADDR";
                FSM_LINE2_DATA  : DEBUG_PSTATE = "LINE2_DATA";
                default         : DEBUG_PSTATE = "UNKNOWN";
            endcase
        end
    `endif

endmodule
