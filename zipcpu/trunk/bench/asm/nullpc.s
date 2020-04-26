;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Filename:	nullpc.s
;
; Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
;
; Purpose:	A quick test of whether or not the prefetch shuts down and
;		idles properly when given an invalid (NULL) address.  This is
; 	intended to be run in the simulator (zippy_tb), as I don't know how I
;	would verify operation on a real device.
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
start:
	CLR	R0
	CLR	R1
	CLR	R2
	CLR	R3
	CLR	R4
	MOV	R0,uR0
	MOV	R0,uR1
	MOV	R0,uR2
	MOV	R0,uR3
	MOV	R0,uR4
	MOV	user_start(PC),uPC
	MOV	R0,uCC
	RTU
	MOV	uCC,R0
	TST	0x100,R0
	BNZ	user_test_worked
	; We could do a BUSY.Z, but then the simulator wouldn't have
	; picked up our stop condition
	BUSY
user_test_worked:
	MOV	user_dive_test(PC),uPC
	RTU
	MOV	uCC,R0
	TST	0x0800,R0
	BRA	user_dive_worked
	BUSY
user_dive_worked:
	; Finally, let's test whether or not a null address from supervisor
	; mode halts the CPU as desired.
	JMP	R1
	NOOP
	NOOP
	; HALT = success.  However, if we halt here we certainly don't have
	; a success.  Hence, signal a test failure by calling a busy instruction
	BUSY	

; Let's see if jumping to a null address creates the exception we want
user_start:
	JMP	R1
	NOOP
	NOOP

; How about divide by zero?
user_dive_test:
	LDI	25,R0
	CLR	R1
	CLR	R2
	DIVS	R1,R0
	ADD	1,R2
	ADD	1,R2
	ADD	1,R2
	ADD	1,R2
	ADD	1,R2
	BUSY
