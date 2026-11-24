# ==================================================
#  LCD pin assignment
#    data  cable -> header labeled 16 17 18 19 20 21 22 23
#    ctrl  cable -> header labeled 24 25 26 27 28 29 30 31
#  board "FPGA GPIO-2" = Altera DE0-Nano GPIO_1 (JP2)
#  DE0-Nano User Manual Table 3-7
# ==================================================
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
export_assignments
