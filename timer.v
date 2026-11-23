// ==================================================
//  * Filename      : timer.v
//  * Description   : Count-down Timer (MM:SS)
//                    설정 -> 시작 -> 00:00 도달 시 버저 요청
// ==================================================
module  timer
#(
    parameter   EXPIRE_SEC = 5      // 00:00 도달 후 버저 유지 시간(초). 0이면 수동 해제까지 유지
)
(
    output      [5:0]   o_min,          // 남은 분
    output      [5:0]   o_sec,          // 남은 초
    output              o_run,          // 카운트다운 중
    output              o_expire,       // 00:00 도달, 버저 요청 레벨
    output              o_expire_start, // 00:00 도달 순간 1클럭 펄스, 알람 곡 처음부터 재생용
    input               i_set_en,       // 타이머 모드일 때 1 (설정은 정지 상태에서만 반영)
    input               i_set_min,      // 분 변경 입력
    input               i_set_sec,      // 초 변경 입력
    input               i_set_dec,      // 1이면 설정 시 감소, 0이면 증가
    input               i_tick,         // 1Hz
    input               i_start,        // 시작 / 일시정지 토글 입력
    input               i_clear,        // 정지 및 00:00 초기화 입력
    input               i_clk,
    input               i_rstn
);
// --------------------------------------------------
//  FSM State
// --------------------------------------------------
    localparam  ST_IDLE     = 2'd0;     // 정지, 설정 가능
    localparam  ST_RUN      = 2'd1;     // 카운트다운 중
    localparam  ST_EXPIRE   = 2'd2;     // 00:00 도달, 버저 요청

    reg         [1:0]   c_state;

// --------------------------------------------------
//  Rising Edge Detector
//  디바운싱된 스위치 신호를 1클럭 펄스로 변환
// --------------------------------------------------
    wire        [4:0]   sync_in;
    reg         [4:0]   sync_d;
    wire        [4:0]   pulse;

    assign  sync_in = {i_tick, i_clear, i_start, i_set_sec, i_set_min};

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            sync_d  <= 5'b0;
        end else begin
            sync_d  <= sync_in;
        end
    end

    assign  pulse = sync_in & ~sync_d;

    wire    pls_set_min = pulse[0];
    wire    pls_set_sec = pulse[1];
    wire    pls_start   = pulse[2];
    wire    pls_clear   = pulse[3];
    wire    pls_tick    = pulse[4];

// --------------------------------------------------
//  Count-down Register
// --------------------------------------------------
    reg         [5:0]   min;
    reg         [5:0]   sec;
    reg         [3:0]   exp_cnt;

    assign  o_min    = min;
    assign  o_sec    = sec;
    reg                 expire_d;

    assign  o_run           = (c_state == ST_RUN);
    assign  o_expire        = (c_state == ST_EXPIRE);
    assign  o_expire_start  = o_expire & ~expire_d;

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            expire_d    <= 1'b0;
        end else begin
            expire_d    <= o_expire;
        end
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            c_state <= ST_IDLE;
            min     <= 6'd0;
            sec     <= 6'd0;
            exp_cnt <= 4'd0;
        end else begin
            case (c_state)
            //  정지 상태: 설정과 시작을 받음
                ST_IDLE: begin
                    if (pls_clear) begin
                        min     <= 6'd0;
                        sec     <= 6'd0;
                    end else if (i_set_en && pls_set_min) begin
                        if (i_set_dec) begin
                            min <= (min == 6'd0)  ? 6'd59 : min - 6'd1;
                        end else begin
                            min <= (min == 6'd59) ? 6'd0  : min + 6'd1;
                        end
                    end else if (i_set_en && pls_set_sec) begin
                        if (i_set_dec) begin
                            sec <= (sec == 6'd0)  ? 6'd59 : sec - 6'd1;
                        end else begin
                            sec <= (sec == 6'd59) ? 6'd0  : sec + 6'd1;
                        end
                    end

                    if (pls_start && !((min == 6'd0) && (sec == 6'd0))) begin
                        c_state <= ST_RUN;
                    end
                end

            //  카운트다운 상태
                ST_RUN: begin
                    if (pls_clear) begin
                        c_state <= ST_IDLE;
                        min     <= 6'd0;
                        sec     <= 6'd0;
                    end else if (pls_start) begin
                        c_state <= ST_IDLE;             // 일시 정지, 남은 시간 유지
                                                        // i_set_en은 동작 중 무시 (ctrl이 타이머 모드 내내 1을 줌)
                    end else if (pls_tick) begin
                        if (sec != 6'd0) begin
                            sec <= sec - 6'd1;
                            if ((min == 6'd0) && (sec == 6'd1)) begin
                                c_state <= ST_EXPIRE;   // 00:01 -> 00:00
                                exp_cnt <= 4'd0;
                            end
                        end else begin
                            min <= min - 6'd1;          // 초 0 -> 분 빌림
                            sec <= 6'd59;
                        end
                    end
                end

            //  종료 상태: 버저 요청
                ST_EXPIRE: begin
                    if (pls_clear || pls_start) begin
                        c_state <= ST_IDLE;
                        min     <= 6'd0;
                        sec     <= 6'd0;
                        exp_cnt <= 4'd0;
                    end else if (pls_tick && (EXPIRE_SEC != 0)) begin
                        if (exp_cnt == (EXPIRE_SEC - 1)) begin
                            c_state <= ST_IDLE;
                            exp_cnt <= 4'd0;
                        end else begin
                            exp_cnt <= exp_cnt + 4'd1;
                        end
                    end
                end

                default: c_state <= ST_IDLE;
            endcase
        end
    end
endmodule
