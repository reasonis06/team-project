// ==================================================
//  * Filename      : clock_cnt.v
//  * Description   : 0 ~ MAX 증감 카운터
//
//  포트는 원본과 같음. i_en 하나만 추가했음
//
//  달라진 점
//    원본 : i_clk이 카운트 신호였음. 그 신호의 상승엣지마다 1씩 변함
//    수정 : i_clk은 50MHz 시스템 클럭. i_en이 1인 클럭에서만 1씩 변함
//    o_max : 레지스터가 아니라 "지금 값이 MAX인가"를 바로 내보냄.
//            자리올림을 쓰는 쪽에서 tick과 같이 보고 판단함
//    리셋값 : MAX -> 0. 자리올림 방식이 바뀌어 MAX로 시작시킬 이유가 없어짐
// ==================================================
module clock_cnt
#(
    parameter MAX = 59
)
(
    output reg [$clog2(MAX+1)-1:0] o_cnt,
    output                         o_max,
    input                          i_en,
    input                          i_clk,
    input                          i_down,
    input                          i_rstn
);

assign o_max = (o_cnt == MAX);

always @(posedge i_clk or negedge i_rstn) begin
    if(!i_rstn) begin
        o_cnt <= 0;
    end else if(i_en) begin
        if(i_down) begin
            o_cnt <= (o_cnt == 0)   ? MAX : o_cnt - 1'b1;
        end else begin
            o_cnt <= (o_cnt == MAX) ? 0   : o_cnt + 1'b1;
        end
    end
end

endmodule
