// ==================================================
//  * Filename      : alarm_cnt.v
//  * Description   : 알람 시각 저장용 0 ~ MAX 증감 카운터
//
//  포트는 원본과 같음. i_en 과 i_down 을 추가했음
//
//  달라진 점
//    i_down 추가. 원본은 증가만 가능해서 감소 버튼을 눌러도 값이 올라갔음
//    i_clk 은 50MHz 시스템 클럭이고 i_en 이 1인 클럭에서만 값이 바뀜
// ==================================================
module alarm_cnt
#(
    parameter MAX = 59
)
(
    output reg [$clog2(MAX+1)-1:0] o_cnt,
    input                          i_en,
    input                          i_down,
    input                          i_clk,
    input                          i_rstn
);

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
