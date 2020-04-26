;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Filename:	ivec.S
;
; Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
;
; Purpose:	Just to test whether or not a timer works as desired.  This
;		will set the timer to interrupt every millisecond, and then
;		update a counter on every interrupt.
;
;		On any failure, the processor will execute a BUSY command.
;
; Creator:	Dan Gisselquist, Ph.D.
;		Gisselquist Technology, LLC
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Copyright (C) 2015, Gisselquist Technology, LLC
;
; This program is free software (firmware): you can redistribute it and/or
; modify it under the terms of  the GNU General Public License as published
; by the Free Software Foundation, either version 3 of the License, or (at
; your option) any later version.
;
; This program is distributed in the hope that it will be useful, but WITHOUT
; ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
; for more details.
;
; License:	GPL, v3, as defined and found on www.gnu.org,
;		http://www.gnu.org/licenses/gpl.html
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Registers:
;	sR0	Peripheral address
;	sR2	Interrupt controller command
;	sR3	Timer peripheral command
;	sR4	User program entry address (Could also be (re)entry address,
;			but isn't in this implementation)
;	sR5	Whether or not we've gotten the first interrupt
;	sR6	Number of times we've been interrupted
;	sR7	Number of times R6 has overflowed
reset:
	CLR	R0		; Load the address of the interrupt controller
	LDIHI	$c000h,R0	; into R0
	LDI	$-1,R2		; Acknowledge and disable all interrupts
	LDIHI	$7fffh,R2	;
	STO	R2,(R0)		;
	; Set the timer for a programmaable interrupt, every 100k clocks,
	; or roughly 1,000 times a second on a 100 MHz clock.
	LDIHI	$0xc001h,R3	; R3 = 100k, save that the top two bits are
	LDILO	$0x86a0h,R3	; also set (start timer, and auto reload)
	STO	R3,$6(C0)
	; Now that timer-C is set, let's enable it's interrupts
	LDIHI	$8004h,R2	; Leaving the bottom all ones acknowledges and
	STO	R2,(R0)		; clears any interrupts (again)
	; Clear our counter variables
	CLR	R5
	CLR	R6
	CLR	R7
	; Program our wait for interrupt routine
	MOV	$8(PC),R4
	MOV	R4,uPC
	RTU
on_first_interrupt:
	ADD	$1,R5
setup_for_next_interrupt:
	RTU
on_subsequent_interrupt:
	ADD	$1,R6
	ADD.C	$1,R7
	BRA	$-4
haltcpu:	
	BUSY			; We've failed if we ever get here

waitforinterrupt:
	WAIT
	BRA	$-2
	MOV	$0,R0
	MOV	$0,R0
	BUSY
