onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/reset_s
add wave -noupdate /tb/clock_s
add wave -noupdate /tb/mode_s
add wave -noupdate -radix hexadecimal /tb/data_i_s
add wave -noupdate -radix hexadecimal /tb/data_o_s
add wave -noupdate /tb/csr_n_s
add wave -noupdate /tb/csw_n_s
add wave -noupdate /tb/wait_n_s
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
add wave -noupdate /tb/u_target/VDPVRAMRDACK
add wave -noupdate /tb/u_target/VDPVRAMRDREQ
add wave -noupdate /tb/u_target/VDPVRAMWRACK
add wave -noupdate /tb/u_target/VDPVRAMWRREQ
add wave -noupdate /tb/u_target/PREWINDOW
add wave -noupdate /tb/u_target/PREWINDOW_X
add wave -noupdate /tb/u_target/PREWINDOW_Y_SP
add wave -noupdate /tb/u_target/SPVRAMACCESSING
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1724050 ns} 0}
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
WaveRestoreZoom {244955 ns} {2638555 ns}
