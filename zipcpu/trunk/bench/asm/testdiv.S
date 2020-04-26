;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Filename:	testdiv.S
;
; Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
;
; Purpose:	Tests the libraries signed division algorithm.
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
;	R12	Peripheral base
;	R11	Address of our one memory variable
;
/* something else */
#include "sys.i"
start:
	LDI	0xc0000000,R12	; Get the address of our peripheral base
	MOV	$1(PC),R11	; Get a memory address for a variable
	BRA	skip_test_variable
test_variable:
	WORD	0
skip_test_variable:
	LDI	$-1,R0	; Start the watchdog timer
	STO	R0,sys.bus.wdt(R12)
	LSR	$1,R0	; R0 now = 0x7fffffff
	STO	R0,sys.bus.tma(R12)
	LSR	$1,R0	; R0 now = 0x3fffffff
	STO	R0,sys.bus.tmb(R12)
	LSR	$1,R0
	STO	R0,sys.bus.tmc(R12)
	;
	CLR	R0
wdt_test_loop:
	ADD	$1,R0
	LOD	(R11),R1
	CMP	R0,R1
	STO.LT	R0,(R11)
	TST	-1,R0
	BLT	wdt_test_program_is_broken
	BRA	wdt_test_loop

wdt_test_program_is_broken:
	HALT










entry:
	; Set up a test program
	MOV	test_div_program(PC),uPC
	MOV	top_of_stack(PC),uSP
	; Run it in user space
	RTU
	; Check for how the result came back: R0 = 0 means success
	MOV	uR11,R11
	TST	-1,R11
	HALT.Z
	BUSY

test_div_program:
	;
	LDI	1,R11
	LDI	5,R0
	LDI	1,R1
	LDI	5,R2
	LDI	0,R3
	MOV	__HERE__+2(PC),R4
	BRA	test_divs

	;
	LDI	2,R11
	LDI	5,R0
	LDI	2,R1
	LDI	2,R2
	LDI	1,R3
	MOV	__HERE__+2(PC),R4
	BRA	test_divs

	;
	LDI	3,R11
	LDI	0xb53d0,R0
	LDI	0x2d,R1
	LDI	16496,R2
	LDI	32,R3
	MOV	__HERE__+2(PC),R4
	BRA	test_divs

	;
	LDI	4,R11
	LDI	2031890191,R0
	LDI	120193795,R1
	LDI	16,R2
	LDI	108789471,R3
	MOV	__HERE__+2(PC),R4
	BRA	test_divs

	;
	LDI	5,R11
	LDI	203553,R0
	LDI	142580994,R1
	LDI	0,R2
	LDI	203553,R3
	MOV	__HERE__+2(PC),R4
	BRA	test_divs

	;
	LDI	6,R11
	LDI	142580994,R0
	LDI	203553,R1
	LDI	700,R2
	LDI	93894,R3
	MOV	__HERE__+2(PC),R4
	BRA	test_divs

	;
	LDI	7,R11
	LDI	142580994,R0
	LDI	2499,R1
	LDI	57055,R2
	LDI	549,R3
	MOV	__HERE__+2(PC),R4
	BRA	test_divs

	;
	LDI	8,R11
	LDI	-142580994,R0
	LDI	2499,R1
	LDI	-57055,R2
	LDI	-549,R3
	MOV	__HERE__+2(PC),R4
	BRA	test_divs

	;
	LDI	9,R11
	LDI	142580994,R0
	LDI	-2499,R1
	LDI	-57055,R2
	LDI	549,R3
	MOV	__HERE__+2(PC),R4
	BRA	test_divs

	;
	LDI	10,R11
	LDI	-142580994,R0
	LDI	-2499,R1
	LDI	57055,R2
	LDI	-549,R3
	MOV	__HERE__+2(PC),R4
	BRA	test_divs

	;
	CLR	R11
	TRAP	0

test_divs:
	;	R0 = Numerator
	;	R1 = Denominator
	;	R2 = Integer result
	;	R3 = Remainder
	;	R4 = Return address
	;	R11= Test failure ID
	MOV	R2,R5
	MOV	R3,R6
	MOV	__HERE__+2(PC),R2
	BRA	lib_divs
	CMP	R0,R5
	BNZ	test_failure
	CMP	R1,R6
	BNZ	test_failure
	JMP	R4
	
test_failure:
	TRAP	0
	NOOP
	BUSY

