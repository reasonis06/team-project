// ==================================================
//  * Filename      : lcd_textgen.v
//  * Description   : 팀프로젝트 LCD 문구 생성 (week11 textgen.v 자리를 대체)
//                    1줄 : 현재 모드 (일반/설정/알람설정/타이머)
//                    2줄 : 알람 시각 + On/Off
//                    textgen_nco 출력(10Hz 구형파)을 valid로 사용
//                    → 0.1초마다 textlcd가 화면을 새로 씀, 입력이 바뀌면 바로 반영
//  * Reuse         : week11 textgen.v 대비
//                    - 고정 문구 4세트 + 5초 카운터 삭제
//                    - 입력(i_mode, 알람 시각, On/Off)으로 문구를 조합 회로로 생성
//                    - textgen_nco는 그대로 재사용, 분주비만 1Hz → 10Hz
//                    - 포트(o_line_data_valid, o_line_data1/2)는 textgen과 동일
// ==================================================
`include    "textgen_nco.v"

module  lcd_textgen
#(
    parameter   FREQDIV = 5000000       // 50MHz → 10Hz (화면 갱신 주기 0.1초)
)
(
    output                  o_line_data_valid,
    output  reg [16*8-1:0]  o_line_data1,
    output  reg [16*8-1:0]  o_line_data2,
    input       [1:0]       i_mode,         // 0:일반 1:설정 2:알람설정 3:타이머
    input       [4:0]       i_alarm_hour,   // 0~23
    input       [5:0]       i_alarm_min,    // 0~59
    input                   i_alarm_en,     // 1:On 0:Off
    input                   i_clk,
    input                   i_rstn
);
// --------------------------------------------------
//  Mode Encoding
// --------------------------------------------------
    localparam  MODE_CLOCK      = 2'd0;
    localparam  MODE_CLOCK_SET  = 2'd1;
    localparam  MODE_ALARM_SET  = 2'd2;
    localparam  MODE_TIMER      = 2'd3;

// --------------------------------------------------
//  Refresh Valid : 10Hz 구형파
//  textlcd가 valid의 상승 에지에서 문구를 받아 화면을 다시 씀
// --------------------------------------------------
    textgen_nco
    #(
        .FREQDIV            (FREQDIV            )
    )
    u_textgen_nco(
        .o_clk              (o_line_data_valid  ),
        .i_clk              (i_clk              ),
        .i_rstn             (i_rstn             )
    );

// --------------------------------------------------
//  숫자 → ASCII : '0'(0x30) + 숫자
// --------------------------------------------------
    wire    [7:0]   char_hour10 = 8'h30 + (i_alarm_hour / 10);
    wire    [7:0]   char_hour1  = 8'h30 + (i_alarm_hour % 10);
    wire    [7:0]   char_min10  = 8'h30 + (i_alarm_min  / 10);
    wire    [7:0]   char_min1   = 8'h30 + (i_alarm_min  % 10);

// --------------------------------------------------
//  Line 1 : 모드 (문자열 왼쪽 글자 = MSB = 화면 첫 칸)
// --------------------------------------------------
    always @(*) begin
        case (i_mode)
            MODE_CLOCK      : o_line_data1 = "MODE: CLOCK     ";
            MODE_CLOCK_SET  : o_line_data1 = "MODE: CLOCK SET ";
            MODE_ALARM_SET  : o_line_data1 = "MODE: ALARM SET ";
            MODE_TIMER      : o_line_data1 = "MODE: TIMER     ";
            default         : o_line_data1 = "MODE: ?         ";
        endcase
    end

// --------------------------------------------------
//  Line 2 : "ALARM HH:MM  ON " / "ALARM HH:MM  OFF"
// --------------------------------------------------
    always @(*) begin
        if (i_alarm_en) begin
            o_line_data2 = {"ALARM ", char_hour10, char_hour1, ":", char_min10, char_min1, "  ON "};
        end else begin
            o_line_data2 = {"ALARM ", char_hour10, char_hour1, ":", char_min10, char_min1, "  OFF"};
        end
    end

endmodule
