;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Filename:	wdt.S
;
; Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
;
; Purpose:	Test to see whether or not the watchdog timer works.  We'll
;		start the watchdog, clear a register, then write as many times
;		as we can to memory before the watchdog kicks in.
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
#include "sys.i"
start:
	LDI	0xc0000000,R12	; Get the address of our peripheral base
	MOV	$1(PC),R11	; Get a memory address for a variable
	BRA	skip_test_variable
test_variable:
	.DAT	0
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
