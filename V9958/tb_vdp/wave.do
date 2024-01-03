onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/reset_s
add wave -noupdate /tb/clock_s
add wave -noupdate /tb/mode_s
add wave -noupdate -radix hexadecimal /tb/data_i_s
add wave -noupdate -radix hexadecimal /tb/data_o_s
add wave -noupdate /tb/req_s
add wave -noupdate /tb/ack_s
add wave -noupdate /tb/wrt_s
add wave -noupdate -divider Outs
add wave -noupdate -radix hexadecimal /tb/rgb_b_s
add wave -noupdate -radix hexadecimal /tb/rgb_g_s
add wave -noupdate -radix hexadecimal /tb/rgb_r_s
add wave -noupdate /tb/hsync_n_s
add wave -noupdate /tb/vsync_n_s
add wave -noupdate /tb/videocs_n_s
add wave -noupdate /tb/video_dhclk_s
add wave -noupdate /tb/video_dlclk_s
add wave -noupdate /tb/blank_s
add wave -noupdate /tb/int_n_s
add wave -noupdate /tb/wait_s
add wave -noupdate -divider VRAM
add wave -noupdate /tb/vram_oe_n_s
add wave -noupdate /tb/vram_we_n_s
add wave -noupdate -radix hexadecimal /tb/vram_addr_s
add wave -noupdate -radix hexadecimal /tb/vram_data_i_s
add wave -noupdate -radix hexadecimal /tb/vram_data_o_s
add wave -noupdate -divider Internal
add wave -noupdate /tb/u_target/DOTSTATE
add wave -noupdate /tb/u_target/EIGHTDOTSTATE
add wave -noupdate -radix unsigned /tb/u_target/H_CNT
add wave -noupdate -radix hexadecimal /tb/u_target/IRAMADR
add wave -noupdate -radix hexadecimal /tb/u_target/PRAMADR
add wave -noupdate -radix hexadecimal /tb/u_target/PRAMADRG123M
add wave -noupdate -radix hexadecimal /tb/u_target/PRAMADRG4567
add wave -noupdate -radix hexadecimal /tb/u_target/PRAMADRSPRITE
add wave -noupdate -radix hexadecimal /tb/u_target/PRAMADRT12
add wave -noupdate -radix hexadecimal /tb/u_target/PRAMDAT
add wave -noupdate -radix hexadecimal /tb/u_target/PRAMDATPAIR
add wave -noupdate -radix hexadecimal /tb/u_target/PREDOTCOUNTER_X
add wave -noupdate -radix hexadecimal /tb/u_target/PREDOTCOUNTER_Y
add wave -noupdate -radix hexadecimal /tb/u_target/PREDOTCOUNTER_YP
add wave -noupdate /tb/u_target/PREWINDOW
add wave -noupdate /tb/u_target/PREWINDOW_SP
add wave -noupdate /tb/u_target/PREWINDOW_X
add wave -noupdate /tb/u_target/PREWINDOW_Y
add wave -noupdate /tb/u_target/PREWINDOW_Y_SP
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {100441 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 210
configure wave -valuecolwidth 49
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {1105 ns} {200145 ns}
