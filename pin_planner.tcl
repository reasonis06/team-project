# ==================================================
#  Quartus Prime Pin Assignment Tcl Script
#  Board      : Altera DE0-Nano (EP4CE22F17C6)
# ==================================================

# --------------------------------------------------
#  전역 I/O 전압 설정 (3.3V 주변장치 호환)
# --------------------------------------------------
set_global_assignment -name STRATIX_DEVICE_IO_STANDARD "3.3-V LVTTL"

# --------------------------------------------------
#  기본 클럭 / 리셋 / 부저 / 모드 LED / 스위치
# --------------------------------------------------
set_location_assignment PIN_R8  -to i_clk
set_location_assignment PIN_J15 -to i_rstn
set_location_assignment PIN_C8  -to o_buzz

set_location_assignment PIN_A13 -to o_mode[1]
set_location_assignment PIN_A15 -to o_mode[0]

set_location_assignment PIN_D11 -to i_sw[7]
set_location_assignment PIN_A12 -to i_sw[6]
set_location_assignment PIN_B11 -to i_sw[5]
set_location_assignment PIN_C11 -to i_sw[4]
set_location_assignment PIN_E10 -to i_sw[3]
set_location_assignment PIN_E11 -to i_sw[2]
set_location_assignment PIN_D9  -to i_sw[1]
set_location_assignment PIN_C9  -to i_sw[0]

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
set_location_assignment PIN_P9  -to o_seg_enb[0]

# --------------------------------------------------
#  Text LCD (DE0-Nano GPIO_1 / JP2)
# --------------------------------------------------
set_location_assignment PIN_N16 -to io_lcd_data[7]
set_location_assignment PIN_R14 -to io_lcd_data[6]
set_location_assignment PIN_P16 -to io_lcd_data[5]
set_location_assignment PIN_P15 -to io_lcd_data[4]
set_location_assignment PIN_L15 -to io_lcd_data[3]
set_location_assignment PIN_R16 -to io_lcd_data[2]
set_location_assignment PIN_K16 -to io_lcd_data[1]
set_location_assignment PIN_L16 -to io_lcd_data[0]
set_location_assignment PIN_L14 -to o_lcd_e
set_location_assignment PIN_N15 -to o_lcd_rs
set_location_assignment PIN_P14 -to o_lcd_rw

# --------------------------------------------------
#  IR 리모컨 수신부
# --------------------------------------------------
set_location_assignment PIN_D3  -to i_ir_rxb
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to i_ir_rxb

# --------------------------------------------------
#  PSD 센서용 DE0-Nano 내장 ADC (ADC128S022)
# --------------------------------------------------
set_location_assignment PIN_B14 -to o_adc_sclk
set_location_assignment PIN_A10 -to o_adc_csn
set_location_assignment PIN_B10 -to o_adc_din
set_location_assignment PIN_A9  -to i_adc_dout

export_assignments
