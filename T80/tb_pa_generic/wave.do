onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/reset_n
add wave -noupdate -radix unsigned /tb/u_target/MCycle
add wave -noupdate -radix unsigned /tb/u_target/TState
add wave -noupdate /tb/clock
add wave -noupdate /tb/clock_enable
add wave -noupdate /tb/clock_enable_n
add wave -noupdate -radix hexadecimal /tb/cpu_a
add wave -noupdate -radix hexadecimal /tb/cpu_di
add wave -noupdate -radix hexadecimal /tb/u_target/DI_Reg
add wave -noupdate -radix hexadecimal -childformat {{/tb/cpu_do(7) -radix hexadecimal} {/tb/cpu_do(6) -radix hexadecimal} {/tb/cpu_do(5) -radix hexadecimal} {/tb/cpu_do(4) -radix hexadecimal} {/tb/cpu_do(3) -radix hexadecimal} {/tb/cpu_do(2) -radix hexadecimal} {/tb/cpu_do(1) -radix hexadecimal} {/tb/cpu_do(0) -radix hexadecimal}} -subitemconfig {/tb/cpu_do(7) {-height 15 -radix hexadecimal} /tb/cpu_do(6) {-height 15 -radix hexadecimal} /tb/cpu_do(5) {-height 15 -radix hexadecimal} /tb/cpu_do(4) {-height 15 -radix hexadecimal} /tb/cpu_do(3) {-height 15 -radix hexadecimal} /tb/cpu_do(2) {-height 15 -radix hexadecimal} /tb/cpu_do(1) {-height 15 -radix hexadecimal} /tb/cpu_do(0) {-height 15 -radix hexadecimal}} /tb/cpu_do
add wave -noupdate /tb/cpu_wait_n
add wave -noupdate /tb/cpu_m1_n
add wave -noupdate /tb/cpu_rfsh_n
add wave -noupdate /tb/cpu_mreq_n
add wave -noupdate /tb/cpu_ioreq_n
add wave -noupdate /tb/cpu_rd_n
add wave -noupdate /tb/cpu_wr_n
add wave -noupdate /tb/cpu_irq_n
add wave -noupdate /tb/cpu_nmi_n
add wave -noupdate /tb/cpu_busreq_n
add wave -noupdate /tb/cpu_halt_n
add wave -noupdate /tb/cpu_busak_n
add wave -noupdate /tb/u_target/CEN
add wave -noupdate /tb/u_target/CEN_pol
add wave -noupdate /tb/u_target/CEN_n
add wave -noupdate /tb/u_target/CEN_p
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {240 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 169
configure wave -valuecolwidth 40
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 2
configure wave -griddelta 20
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {13126 ns}
