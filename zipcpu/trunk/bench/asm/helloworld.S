;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Filename:	helloworld.S
;
; Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
;
; Purpose:	A test of whether or not we can scroll a message on a
;		seven segment display.  This depends upon the seven segment
;		display driver (not included) being installed at position
;		0x15 in memory.  If so, this scrolls the message:
;		"HELLO UJorld." across the 4 seven segment display digits.
;
;		This test discovered that right shifting by 31 or more did
;		not result in zero as desired.  It also discovered that the
;		.DAT assembly instruction did not function as desired.  Both
;		bugs were fixed to get this to work.
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
; Register map
;	R12 peripherals
;	R11  timer length
;	R10  value to clear/reset the PIC
;	uR12 = memory
;	uR11 = rawsseg
; 	uR9  = state
;	R8   = new value for SSEG
build_supervisor_state:
	CLR	R12		; Load a pointer to our peripherals
	LDIHI	$c000h,R12
	LDI	$5f5e1h,R11	; An amount to reset the timer to: 1/4 sec
	LSL	$6,R11
	LDIHI	$8010h,R10	; A value to clear/reset the PIC for timerA ints
	LDILO	$ffffh,R10
	MOV	$1+PC,uR12	; User memory (so this isn't supervisor state..)
	BRA	$4
	.DAT	$0x6e9e1c1c	; Raw SSEG for 'HELL'
	.DAT	$0xfc007c70	; Raw SSEG for 'O UJ'
	.DAT	$0x3a0a607b	; Raw SSEG for 'orld.'
	.DAT	$0x00000000	; Raw SSEG for '    '
build_user_state:
	LDI	$15h,R0
	MOV	R0,uR11
	MOV	$6+PC,uPC
	CLR	R0
	MOV	R0,uR9
repeat:
	STO	R11,$4(R12)	; Reset the timer
	STO	R10,(R12)	; Reset the PIC
	RTU
	BRA	$-4
user_task:
	MOV	R9,R0
	LSR	$2,R0
	ADD	R12,R0
	LOD	(R0),R8		; Read the left word
	MOV	R9,R1		; Rotate it into place
	AND	$3,R1
	LSL	$3,R1		; Multiply by eight
	LSL	R1,R8		; Shift words to left by 0,8,16,24 bits

	ADD	$1,R0		; Calculate address of next word
	CMP	$4+R12,R0
	SUB.GE	$4,R0
	LOD	(R0),R2		; Load the next word into a building location
	LDI	$32,R3
	SUB	R1,R3
	LSR	R3,R2
	OR	R2,R8		; Put the two together

	STO	R8,(R11)	; Store the result

	ADD	$1,R9		; Increment our state
	AND	$15,R9

	WAIT			; Wait for the next interrupt
	BRA	$-21		; Back up to the top to start over

	BREAK
	BREAK
	BREAK
