// ==================================================
//  * Filename      : timer_top.v
//  * Description   : 타이머 기능 단독 검증용 Top
// ==================================================
`include    "ctrl_nco.v"
`include    "ctrl_debouncer.v"
`include    "timer.v"
`include    "buzzer.v"
`include    "ssegdisp.v"

module  timer_top
(
    output              o_buzzer,
    output      [5:0]   o_seg_enb,
    output      [7:0]   o_seg,
    input       [7:0]   i_sw,
    input               i_clk,
    input               i_rstn
);
// --------------------------------------------------
//  Debouncer & 1Hz
// --------------------------------------------------
    wire        [7:0]   sw;
    wire                clk_1hz;

    ctrl_debouncer
    #(
        .FREQDIV        (5000000            )
    )
    u_ctrl_debouncer(
        .o_sw           (sw                 ),
        .i_sw           (i_sw               ),
        .i_clk          (i_clk              ),
        .i_rstn         (i_rstn             )
    );

    ctrl_nco
    #(
        .FREQDIV        (50000000           )
    )
    u_ctrl_nco(
        .o_clk          (clk_1hz            ),
        .i_clk          (i_clk              ),
        .i_rstn         (i_rstn             )
    );

// --------------------------------------------------
//  Mode & Target
//  sw[0] : 설정 모드 ON/OFF 토글
//  sw[1] : 설정 대상 초 <-> 분 토글
// --------------------------------------------------
    reg                 set_en;
    reg                 targ;           // 0: 초, 1: 분

    always @(posedge sw[0] or negedge i_rstn) begin
        if (!i_rstn) begin
            set_en  <= 1'b0;
        end else begin
            set_en  <= ~set_en;
        end
    end

    always @(posedge sw[1] or negedge i_rstn) begin
        if (!i_rstn) begin
            targ    <= 1'b0;
        end else begin
            targ    <= ~targ;
        end
    end

    wire    set_min = (set_en && (targ == 1'b1)) ? ~sw[2] : 1'b0;
    wire    set_sec = (set_en && (targ == 1'b0)) ? ~sw[2] : 1'b0;

// --------------------------------------------------
//  Timer
// --------------------------------------------------
    wire        [5:0]   t_min;
    wire        [5:0]   t_sec;
    wire                t_run;
    wire                t_expire;
    wire                t_expire_start;

    timer
    #(
        .EXPIRE_SEC     (5                  )
    )
    u_timer(
        .o_min          (t_min              ),
        .o_sec          (t_sec              ),
        .o_run          (t_run              ),
        .o_expire       (t_expire           ),
        .o_expire_start (t_expire_start     ),
        .i_set_en       (set_en             ),
        .i_set_min      (set_min            ),
        .i_set_sec      (set_sec            ),
        .i_set_dec      (~i_sw[3]           ),  // 누르고 있는 동안 감소
        .i_tick         (clk_1hz            ),
        .i_start        (~sw[4]             ),
        .i_clear        (~sw[5]             ),
        .i_clk          (i_clk              ),
        .i_rstn         (i_rstn             )
    );

// --------------------------------------------------
//  Buzzer
// --------------------------------------------------
    buzzer
    u_buzzer(
        .o_out          (o_buzzer           ),
        .i_enb          (~t_expire          ),  // active-low enable
        .i_clk          (i_clk              ),
        .i_rstn         (i_rstn             )
    );

// --------------------------------------------------
//  7-Segment Display : FF MM.SS
// --------------------------------------------------
    wire        [3:0]   num0 = t_sec % 10;
    wire        [3:0]   num1 = t_sec / 10;
    wire        [3:0]   num2 = t_min % 10;
    wire        [3:0]   num3 = t_min / 10;

    ssegdisp
    #(
        .FREQDIV        (5000               )
    )
    u_ssegdisp(
        .o_seg_enb      (o_seg_enb          ),
        .o_seg          (o_seg              ),
        .i_num0         (num0               ),
        .i_num1         (num1               ),
        .i_num2         (num2               ),
        .i_num3         (num3               ),
        .i_num4         (4'd15              ),
        .i_num5         (4'd15              ),
        .i_dp0          (1'b0               ),
        .i_dp1          (1'b0               ),
        .i_dp2          (1'b1               ),
        .i_dp3          (1'b0               ),
        .i_dp4          (1'b0               ),
        .i_dp5          (1'b0               ),
        .i_clk          (i_clk              ),
        .i_rstn         (i_rstn             )
    );
endmodule
