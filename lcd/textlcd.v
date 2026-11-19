// ==================================================
//  * Filename      : textlcd.v
//  * Description   : Text LCD(KS0066) 컨트롤러, 8bit 버스
//                    초기화 명령 → Line1 주소+16글자 → Line2 주소+16글자 → Return Home
//                    매 명령 뒤 BUSY_CHECK에서 BF(DB7)=0이 될 때까지 대기
//  * Modified      : 강의 코드 대비 수정
//                    1) FSM 레지스터 선언을 사용 위치(busy_flag 블록)보다 앞으로 이동
//                    2) n_state / 출력 조합 always에 default 추가 (래치 방지)
//                    3) DEBUG용 p_state 문자열(DEBUG_PSTATE) 추가
//  * Team Project  : week11 textlcd.v 재사용, 팀프로젝트용으로 2곳 수정
//                    4) LCD_DISP_ONOFF 0x0F → 0x0C : 커서/커서 깜빡임 OFF
//                       (화면을 계속 갱신하므로 커서가 보이면 지저분함)
//                    5) init_done 추가 : 초기화(Clear~Entry Set)는 리셋 후 1번만,
//                       이후 갱신은 Return Home → Line1 → Line2만 반복
//                       (매번 Clear하면 갱신할 때마다 화면이 깜빡임)
// ==================================================
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
// --------------------------------------------------
//  Bidirectional I/O
//  R/W=1(읽기)일 때 FPGA는 버스를 놓음(Z) → LCD가 BF/AC를 구동
// --------------------------------------------------
    reg     [7:0]   lcd_data;
    assign          io_lcd_data = o_lcd_rw ? 8'hzz : lcd_data;

// --------------------------------------------------
//  Reference Clock : 50MHz / 50 = 1MHz
// --------------------------------------------------
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

// --------------------------------------------------
//  Timing Control
//  cnt_timing : 0→1→2→3 (1us씩) = clk_ref 1주기(4us)
//  clk_ref    : cnt_timing 3→0 순간 상승 → 상태/RS/RW/DATA 변경
//  o_lcd_e    : cnt_timing 1,2 동안 High (데이터 안정 후 E 펄스)
// --------------------------------------------------
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
        if (^cnt_timing) begin          // 01, 10 → XOR = 1
            o_lcd_e     = 1'b1;
        end else begin
            o_lcd_e     = 1'b0;
        end
    end

// --------------------------------------------------
//  Receive Line Data
//  valid를 clk_ref로 2단 샘플링 → 01 패턴(상승 에지)에서 1클럭 펄스
// --------------------------------------------------
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

// --------------------------------------------------
//  Instructions {RS, R/W, DATA[7:0]} & FSM State
// --------------------------------------------------
    localparam  LCD_BUSY_CHECK  = 10'b01_zzzz_zzzz;    // BF/AC 읽기
    localparam  LCD_RETURN_HOME = 10'b00_0000_0010;    // 0x02
    localparam  LCD_FUNC_SET    = 10'b00_0011_1100;    // 0x3C : DL=1(8bit), N=1(2줄), F=1
    localparam  LCD_DISP_ONOFF  = 10'b00_0000_1100;    // 0x0C : D=1, C=0, B=0 (수정 4)
    localparam  LCD_DISP_CLEAR  = 10'b00_0000_0001;    // 0x01
    localparam  LCD_ENTR_SET    = 10'b00_0000_0110;    // 0x06 : I/D=1, SH=0
    localparam  LCD_DDRAM_ADDR1 = 10'b00_1000_0000;    // 0x80 : DDRAM 0x00 (1줄 시작)
    localparam  LCD_DDRAM_ADDR2 = 10'b00_1100_0000;    // 0xC0 : DDRAM 0x40 (2줄 시작)
    localparam  LCD_DDRAM_WDATA = 2'b10;               // RS=1, R/W=0 : 데이터 쓰기

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

// --------------------------------------------------
//  Busy Flag : BUSY_CHECK 중 cnt_timing==2(E High 끝)에서 DB7 샘플
// --------------------------------------------------
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

// --------------------------------------------------
//  Char Counter : DATA 상태 1번마다 +1, 4bit라 15 다음 0으로 wrap
// --------------------------------------------------
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

// --------------------------------------------------
//  Init Done (수정 5) : ENTR_SET 명령을 한 번 보내면 1, 리셋 전까지 유지
// --------------------------------------------------
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

// --------------------------------------------------
//  FSM : State Register
//  BF=1이면 무조건 BUSY_CHECK 유지
//  p_state : BUSY_CHECK 직전에 실행한 명령 상태 기억
// --------------------------------------------------
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

// --------------------------------------------------
//  FSM : Next State Logic
//  명령 상태 → (항상) BUSY_CHECK → p_state를 보고 다음 명령 결정
// --------------------------------------------------
    always @(*) begin
        case (c_state)
            FSM_RETURN_HOME : n_state = line_data_valid ? FSM_BUSY_CHECK : FSM_RETURN_HOME;
            FSM_BUSY_CHECK  : begin
                case (p_state)
                    FSM_RETURN_HOME : n_state = init_done ? FSM_LINE1_ADDR : FSM_DISP_CLEAR;   // 수정 5
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

// --------------------------------------------------
//  FSM : Output Logic {RS, R/W, DATA}
//  DATA 상태 : line_data의 MSB쪽부터 cnt_char번째 바이트 선택
//              [a -: 8] = [a : a-7]
// --------------------------------------------------
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
            default         :   {o_lcd_rs, o_lcd_rw, lcd_data}  = LCD_BUSY_CHECK;   // 읽기 모드 = 버스 구동 안 함
        endcase
    end

// --------------------------------------------------
//  Debug : GTKWave에서 Data Format → ASCII로 상태 이름 확인
// --------------------------------------------------
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
