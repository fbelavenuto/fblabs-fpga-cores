onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/reset_n
add wave -noupdate /tb/texto
add wave -noupdate -radix unsigned /tb/u_target/m_cycle_s
add wave -noupdate -radix unsigned /tb/u_target/t_state_s
add wave -noupdate /tb/clock
add wave -noupdate -radix hexadecimal /tb/cpu_a
add wave -noupdate -radix hexadecimal /tb/cpu_di
add wave -noupdate -radix hexadecimal /tb/u_target/data_r
add wave -noupdate -radix hexadecimal /tb/cpu_do
add wave -noupdate /tb/cpu_irq_n
add wave -noupdate /tb/cpu_nmi_n
add wave -noupdate /tb/cpu_wait_n
add wave -noupdate /tb/cpu_m1_n
add wave -noupdate /tb/cpu_rfsh_n
add wave -noupdate /tb/cpu_ioreq_n
add wave -noupdate /tb/cpu_mreq_n
add wave -noupdate /tb/cpu_rd_n
add wave -noupdate /tb/cpu_wr_n
add wave -noupdate /tb/cpu_busreq_n
add wave -noupdate /tb/cpu_busak_n
add wave -noupdate /tb/cpu_halt_n
add wave -noupdate /tb/u_target/wait_s
add wave -noupdate /tb/u_target/u0/IOWait
add wave -noupdate /tb/u_target/u0/Auto_Wait_t1
add wave -noupdate /tb/u_target/u0/Auto_Wait_t2
add wave -noupdate /tb/u_target/u0/Really_Wait
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {180 ns} 0}
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
configure wave -gridperiod 80
configure wave -griddelta 20
configure wave -timeline 1
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {6156 ns}
