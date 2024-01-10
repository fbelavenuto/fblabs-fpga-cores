onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/reset_s
add wave -noupdate /tb/clock_s
add wave -noupdate -radix hexadecimal /tb/data_i_s
add wave -noupdate -radix hexadecimal /tb/data_o_s
add wave -noupdate /tb/write_en_s
add wave -noupdate /tb/read_en_s
add wave -noupdate /tb/empty_s
add wave -noupdate /tb/half_s
add wave -noupdate /tb/full_s
add wave -noupdate -divider Internal
add wave -noupdate -radix hexadecimal /tb/u_target/fifo_proc/memory_v
add wave -noupdate /tb/u_target/fifo_proc/head_v
add wave -noupdate /tb/u_target/fifo_proc/tail_v
add wave -noupdate /tb/u_target/fifo_proc/size_v
add wave -noupdate /tb/u_target/fifo_proc/looped_v
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1175 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 223
configure wave -valuecolwidth 40
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
WaveRestoreZoom {0 ns} {6512 ns}
