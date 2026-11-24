// ==================================================
//  * Filename      : textlcd_nco.v
//  * Description   : textlcd 기준 클럭 분주기
//                    50MHz / FREQDIV(50) = 1MHz (tclk = 1us)
//  * Reuse         : week10 ir_nco.v 구조 재사용
//                    - 모듈명만 textlcd_nco로 변경
//                    - 리셋 시 cnt를 0으로 초기화 (첫 토글이 FREQDIV/2 클럭 뒤에 발생)
// ==================================================
module  textlcd_nco
#(
    parameter       FREQDIV = 50
)
(
    output reg      o_clk,
    input           i_clk,
    input           i_rstn
);
    reg     [$clog2(FREQDIV/2)-1:0]     cnt;

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            cnt     <= 0;
            o_clk   <= 1'b0;
        end else begin
            if (cnt >= FREQDIV/2 - 1) begin
                cnt     <= 0;
                o_clk   <= ~o_clk;
            end else begin
                cnt     <= cnt + 1;
                o_clk   <= o_clk;
            end
        end
    end
endmodule
