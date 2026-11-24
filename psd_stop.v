// ==================================================
//  * Filename      : psd_stop.v
//  * Description   : PSD 센서 값으로 "손이 가까이 왔는지" 판정
//                    알람·타이머 버저를 손으로 끄는 데 씀
//
//  PSD는 가까울수록 값이 커짐 (10주차 측정: 손 없음 0x136, 손 가까이 0x91A)
//  켜짐/꺼짐 기준을 다르게 둬서(히스테리시스) 경계에서 떨리지 않게 함
//  또 HOLD 클럭 동안 같은 상태가 유지돼야 인정해서 노이즈를 거름
// ==================================================
module  psd_stop
#(
    parameter   TH_ON  = 12'h400,   // 이 값 이상이면 손이 가까움 (측정: 손 없음 0x0xx, 손 0x7A9)
    parameter   TH_OFF = 12'h200,   // 이 값 이하로 내려가야 멀어진 것으로 봄
    parameter   HOLD   = 500000     // 판정 유지 클럭 수 (50MHz 기준 10ms)
)
(
    output reg          o_near,     // 손이 가까이 있는 동안 1
    output              o_detect,   // 가까워지는 순간 1클럭 펄스
    input       [11:0]  i_data,
    input               i_clk,
    input               i_rstn
);

    reg [$clog2(HOLD)-1:0] cnt;

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            o_near <= 1'b0;
            cnt    <= 0;
        end else if (!o_near) begin
            if (i_data >= TH_ON) begin
                if (cnt == HOLD - 1) begin
                    o_near <= 1'b1;
                    cnt    <= 0;
                end else begin
                    cnt    <= cnt + 1'b1;
                end
            end else begin
                cnt <= 0;
            end
        end else begin
            if (i_data <= TH_OFF) begin
                if (cnt == HOLD - 1) begin
                    o_near <= 1'b0;
                    cnt    <= 0;
                end else begin
                    cnt    <= cnt + 1'b1;
                end
            end else begin
                cnt <= 0;
            end
        end
    end

    // 상승엣지 검출
    reg near_d;

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)    near_d <= 1'b0;
        else            near_d <= o_near;
    end

    assign o_detect = o_near & ~near_d;

endmodule
