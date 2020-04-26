onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/reset_n_s
add wave -noupdate /tb/clock_s
add wave -noupdate -radix hexadecimal /tb/cpu_addr_s
add wave -noupdate -radix hexadecimal /tb/cpu_di_s
add wave -noupdate -radix hexadecimal /tb/cpu_do_s
add wave -noupdate /tb/sync_s
add wave -noupdate /tb/cpu_we_n_s
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {9000 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 184
configure wave -valuecolwidth 75
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
WaveRestoreZoom {0 ns} {31728 ns}
