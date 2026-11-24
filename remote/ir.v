`include "ir_nco.v"

module ir (
    output reg [31:0] o_data,
    output            o_ir_rst,       // 1. 되돌리기 (0xFD609F) : 전체 리셋
    output     [5:0]  o_ir_key,       // [0]메뉴, [1]오른쪽, [2]+, [3]-, [4]OK, [5]전원
    output            o_ir_targ_prev, // 4. 왼쪽 화살표 (0xFD10EF) : 자릿수 역방향
    input             i_ir_rxb,
    input             i_clk,
    input             i_rstn
);

    // --------------------------------------------------
    // 리모컨 버튼 코드 정의 (하위 24비트 기준)
    // --------------------------------------------------
    localparam CODE_RESET     = 24'hFD609F; // 1. 되돌리기 : 전원 인가 및 리셋
    localparam CODE_MODE      = 24'hFD40BF; // 2. 메뉴     : 모드 전환 (sw[0])
    localparam CODE_TARG_NEXT = 24'hFD50AF; // 3. 오른쪽   : 자릿수 정방향 (sw[1])
    localparam CODE_TARG_PREV = 24'hFD10EF; // 4. 왼쪽     : 자릿수 역방향
    localparam CODE_UP        = 24'hFD20DF; // 5. 플러스   : 값 증가 (sw[2])
    localparam CODE_DOWN      = 24'hFD30DF; // 6. 마이너스 : 값 감소 (sw[3])
    localparam CODE_OK        = 24'hFD906F; // 7. OK       : 시작 / 일시정지 (sw[4])
    localparam CODE_CLEAR     = 24'hFD00FF; // 8. 전원     : 타이머 초기화 (sw[5])

    localparam LEADCODE = 1'b0;
    localparam DATACODE = 1'b1;

    // --------------------------------------------------
    // 1MHz 샘플링 클럭 생성
    // --------------------------------------------------
    wire clk_1M;

    ir_nco #(
        .FREQDIV (50)
    ) u_ir_nco (
        .o_clk   (clk_1M),
        .i_clk   (i_clk),
        .i_rstn  (i_rstn)
    );

    // --------------------------------------------------
    // IR 입력 동기화 및 에지 검출
    // --------------------------------------------------
    wire ir_rx = ~i_ir_rxb;

    reg [1:0] seq_rx;
    always @(posedge clk_1M or negedge i_rstn) begin
        if (!i_rstn) begin
            seq_rx <= 2'b00;
        end else begin
            seq_rx <= {seq_rx[0], ir_rx};
        end
    end

    // High / Low 구간 길이 카운트 (1us 단위)
    reg [15:0] cnt_l;
    reg [15:0] cnt_h;

    always @(posedge clk_1M or negedge i_rstn) begin
        if (!i_rstn) begin
            cnt_l <= 16'd0;
            cnt_h <= 16'd0;
        end else begin
            case (seq_rx)
                2'b00: cnt_l <= cnt_l + 16'd1;
                2'b01: begin
                    cnt_l <= 16'd0;
                    cnt_h <= 16'd0;
                end
                2'b10: begin
                    cnt_l <= cnt_l;
                    cnt_h <= cnt_h;
                end
                2'b11: cnt_h <= cnt_h + 16'd1;
            endcase
        end
    end

    // --------------------------------------------------
    // NEC 프로토콜 FSM
    // --------------------------------------------------
    reg       c_state;
    reg       n_state;
    reg [4:0] cnt;

    always @(posedge clk_1M or negedge i_rstn) begin
        if (!i_rstn) begin
            c_state <= LEADCODE;
        end else if (seq_rx == 2'b01) begin
            c_state <= n_state;
        end
    end

    always @(posedge clk_1M or negedge i_rstn) begin
        if (!i_rstn) begin
            cnt <= 5'd0;
        end else if (c_state == LEADCODE) begin
            cnt <= 5'd0;
        end else if (seq_rx == 2'b01) begin
            cnt <= cnt + 5'd1;
        end
    end

    always @(*) begin
        case (c_state)
            LEADCODE: begin
                if (cnt_h >= 16'd8500 && cnt_l >= 16'd4000)
                    n_state = DATACODE;
                else
                    n_state = LEADCODE;
            end
            DATACODE: begin
                if (cnt == 5'd31)
                    n_state = LEADCODE;
                else
                    n_state = DATACODE;
            end
            default: n_state = LEADCODE;
        endcase
    end

    // 데이터 비트 판별 (Low 구간 1000us 초과 시 '1')
    reg rx_bit;
    always @(*) begin
        if (c_state == DATACODE && cnt_l > 16'd1000)
            rx_bit = 1'b1;
        else
            rx_bit = 1'b0;
    end

    // 32비트 시프트 저장 및 수신 완료 플래그 생성
    reg rx_done_1m;
    always @(posedge clk_1M or negedge i_rstn) begin
        if (!i_rstn) begin
            o_data     <= 32'd0;
            rx_done_1m <= 1'b0;
        end else begin
            if (c_state == DATACODE && seq_rx == 2'b01) begin
                o_data     <= {o_data[30:0], rx_bit};
                rx_done_1m <= (cnt == 5'd31);
            end else begin
                rx_done_1m <= 1'b0;
            end
        end
    end

    // --------------------------------------------------
    // 50MHz 시스템 클럭 도메인으로 동기화 (1클럭 펄스 생성)
    // --------------------------------------------------
    reg [1:0] rx_done_sync;
    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            rx_done_sync <= 2'b00;
        end else begin
            rx_done_sync <= {rx_done_sync[0], rx_done_1m};
        end
    end

    wire rx_pulse = (rx_done_sync == 2'b01);

    // --------------------------------------------------
    // 8가지 버튼 디코딩 (각각 50MHz 1클럭 펄스 출력)
    // --------------------------------------------------
    assign o_ir_rst       = rx_pulse && (o_data[23:0] == CODE_RESET);
    assign o_ir_key[0]    = rx_pulse && (o_data[23:0] == CODE_MODE);
    assign o_ir_key[1]    = rx_pulse && (o_data[23:0] == CODE_TARG_NEXT);
    assign o_ir_targ_prev = rx_pulse && (o_data[23:0] == CODE_TARG_PREV);
    assign o_ir_key[2]    = rx_pulse && (o_data[23:0] == CODE_UP);
    assign o_ir_key[3]    = rx_pulse && (o_data[23:0] == CODE_DOWN);
    assign o_ir_key[4]    = rx_pulse && (o_data[23:0] == CODE_OK);
    assign o_ir_key[5]    = rx_pulse && (o_data[23:0] == CODE_CLEAR);

endmodule