// ==================================================
//  * Filename      : lcd_top.v
//  * Description   : 팀프로젝트 Text LCD 파트 Top
//                    lcd_textgen(문구 생성) → textlcd(LCD 구동)
//                    통합 시 이 모듈 하나만 인스턴스하면 됨
//  * Reuse         : week11 top.v 구조 그대로
//                    - textgen → lcd_textgen 교체, 모드/알람 입력 포트 추가
//                    - TEXT_FREQDIV : lcd_textgen 갱신 주기 분주비
// ==================================================
`include    "textlcd.v"
`include    "lcd_textgen.v"

module  lcd_top
#(
    parameter   TEXT_FREQDIV = 5000000      // 50MHz → 10Hz
)
(
    output              o_lcd_e,
    output              o_lcd_rs,
    output              o_lcd_rw,
    inout       [7:0]   io_lcd_data,
    input       [1:0]   i_mode,             // 0:일반 1:설정 2:알람설정 3:타이머
    input       [4:0]   i_alarm_hour,
    input       [5:0]   i_alarm_min,
    input               i_alarm_en,
    input               i_clk,
    input               i_rstn
);
    wire                    line_data_valid;
    wire        [16*8-1:0]  line_data1;
    wire        [16*8-1:0]  line_data2;

    lcd_textgen
    #(
        .FREQDIV            (TEXT_FREQDIV       )
    )
    u_lcd_textgen(
        .o_line_data_valid  (line_data_valid    ),
        .o_line_data1       (line_data1         ),
        .o_line_data2       (line_data2         ),
        .i_mode             (i_mode             ),
        .i_alarm_hour       (i_alarm_hour       ),
        .i_alarm_min        (i_alarm_min        ),
        .i_alarm_en         (i_alarm_en         ),
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
