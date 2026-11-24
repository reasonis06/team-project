# ==================================================
#  Quartus Prime Pin Assignment Tcl Script
#  Top Module : setting_top (with IR Remote Control)
#  Board      : Altera DE0-Nano
# ==================================================

# --------------------------------------------------
#  기본 클럭 / 리셋 / 부저 / 스위치
# --------------------------------------------------
set_location_assignment PIN_R8 -to i_clk
set_location_assignment PIN_J15 -to i_rstn
set_location_assignment PIN_C8 -to o_buzzer

set_location_assignment PIN_D11 -to i_sw[7]
set_location_assignment PIN_A12 -to i_sw[6]
set_location_assignment PIN_B11 -to i_sw[5]
set_location_assignment PIN_C11 -to i_sw[4]
set_location_assignment PIN_E10 -to i_sw[3]
set_location_assignment PIN_E11 -to i_sw[2]
set_location_assignment PIN_D9 -to i_sw[1]
set_location_assignment PIN_C9 -to i_sw[0]

# --------------------------------------------------
#  7-Segment Display
# --------------------------------------------------
set_location_assignment PIN_F13 -to o_seg[7]
set_location_assignment PIN_T15 -to o_seg[6]
set_location_assignment PIN_T14 -to o_seg[5]
set_location_assignment PIN_T13 -to o_seg[4]
set_location_assignment PIN_R13 -to o_seg[3]
set_location_assignment PIN_T12 -to o_seg[2]
set_location_assignment PIN_R12 -to o_seg[1]
set_location_assignment PIN_T11 -to o_seg[0]

set_location_assignment PIN_T10 -to o_seg_enb[5]
set_location_assignment PIN_R11 -to o_seg_enb[4]
set_location_assignment PIN_P11 -to o_seg_enb[3]
set_location_assignment PIN_R10 -to o_seg_enb[2]
set_location_assignment PIN_N12 -to o_seg_enb[1]
set_location_assignment PIN_P9 -to o_seg_enb[0]

# --------------------------------------------------
#  Text LCD (DE0-Nano GPIO_1 / JP2)
# --------------------------------------------------
set_location_assignment PIN_L16 -to io_lcd_data[0]
set_location_assignment PIN_K16 -to io_lcd_data[1]
set_location_assignment PIN_R16 -to io_lcd_data[2]
set_location_assignment PIN_L15 -to io_lcd_data[3]
set_location_assignment PIN_P15 -to io_lcd_data[4]
set_location_assignment PIN_P16 -to io_lcd_data[5]
set_location_assignment PIN_R14 -to io_lcd_data[6]
set_location_assignment PIN_N16 -to io_lcd_data[7]
set_location_assignment PIN_N15 -to o_lcd_rs
set_location_assignment PIN_P14 -to o_lcd_rw
set_location_assignment PIN_L14 -to o_lcd_e

# --------------------------------------------------
#  IR 리모컨 수신부 (사용하는 보드의 IR 수신 핀 번호로 수정하세요)
# --------------------------------------------------
set_location_assignment PIN_D12 -to i_ir_rxb

export_assignments
