onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/clock_s
add wave -noupdate /tb/reset_s
add wave -noupdate -divider Audio
add wave -noupdate /tb/pcm_li_s
add wave -noupdate /tb/pcm_ri_s
add wave -noupdate /tb/pcm_lo_s
add wave -noupdate /tb/pcm_ro_s
add wave -noupdate -divider I2S
add wave -noupdate /tb/i2s_mclk_s
add wave -noupdate /tb/i2s_bclk_s
add wave -noupdate /tb/i2s_lrclk_s
add wave -noupdate /tb/i2s_di_s
add wave -noupdate /tb/i2s_do_s
add wave -noupdate -divider Internal
add wave -noupdate /tb/u_target/shiftreg
add wave -noupdate /tb/u_target/bdivider
add wave -noupdate /tb/u_target/bdivider_top
add wave -noupdate /tb/u_target/bitcount
add wave -noupdate /tb/u_target/lrdivider
add wave -noupdate /tb/u_target/lrdivider_top
add wave -noupdate /tb/u_target/mclk_r
add wave -noupdate /tb/u_target/nbits
add wave -noupdate /tb/u_target/ratio_mclk_fs
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {12625 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 173
configure wave -valuecolwidth 40
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 5
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {72762 ns}
