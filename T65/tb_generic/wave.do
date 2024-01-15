onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/texto
add wave -noupdate /tb/reset_n_s
add wave -noupdate /tb/clock_s
add wave -noupdate /tb/clock_en_s
add wave -noupdate -radix hexadecimal /tb/cpu_addr_s
add wave -noupdate -radix hexadecimal /tb/cpu_di_s
add wave -noupdate -radix hexadecimal /tb/cpu_do_s
add wave -noupdate /tb/sync_s
add wave -noupdate /tb/cpu_we_n_s
add wave -noupdate -divider Internal
add wave -noupdate -radix unsigned /tb/u_target/MCycle
add wave -noupdate -radix hexadecimal /tb/u_target/PC
add wave -noupdate -radix hexadecimal /tb/u_target/AD
add wave -noupdate -radix hexadecimal /tb/u_target/BAH
add wave -noupdate -radix hexadecimal /tb/u_target/DL
add wave -noupdate -radix hexadecimal /tb/u_target/IR
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {6100 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 143
configure wave -valuecolwidth 40
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 100
configure wave -gridperiod 1000
configure wave -griddelta 2
configure wave -timeline 1
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {95328 ns}
