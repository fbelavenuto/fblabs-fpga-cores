;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Filename:	divu.S
;
; Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
;
; Purpose:	Zip assembly file for running doing an unsigned divide.
;		This routine is also called by the signed divide.
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
;
;
lib_divu:	; Given R0,R1, computer R0 = R0/R1 and R1 = R0%R1
	TST	-1,R1
	; BNZ	divu_valid_divide
	CLR.Z	R0		; Should be a divide by zero error / trap
	JMP.Z	R2
divu_valid_divide:
	SUB	2,SP
	STO	R2,(SP)
	STO	R3,1(SP)
	;
	LDI	1,R2	; Here's where we record the bit we are working on
	CLR	R3	; Here's where we build our result
; Our original loop rejoin point, before a touch of unrolling
	CMP	R1,R0
	BRC	divu_prep_next_bit
	TST	-1,R1
	BLT	divu_top_bit_set
divu_rotate_up_r1:
	LSL	1,R2
	LSL	1,R1
/*
	CMP	R1,R0
	BRC	divu_prep_next_bit
	TST	-1,R1
	BGT	divu_rotate_up_r1
*/
	BLT	divu_top_bit_set
	CMP	R1,R0
	BRC	divu_prep_next_bit
	;
	LSL	1,R2
	LSL	1,R1
	BLT	divu_top_bit_set
	CMP	R1,R0
	BRC	divu_prep_next_bit
	;
	LSL	1,R2
	LSL	1,R1
	BLT	divu_top_bit_set
	CMP	R1,R0
	BRC	divu_prep_next_bit
	;
	LSL	1,R2
	LSL	1,R1
	BLT	divu_top_bit_set
	CMP	R1,R0
	BRC	divu_prep_next_bit
	BRA	divu_rotate_up_r1

divu_top_bit_set:
	CMP	R1,R0
	BRC	divu_prep_next_bit
	SUB	R1,R0
	OR	R2,R3
divu_prep_next_bit:
	LSR	1,R1
	LSR	1,R2
	BZ	divu_record_result
	;
divu_next_loop:
	CMP	R1,R0		;
	SUB.GE	R1,R0		; We also switch to signed arithmetic, since
	OR.GE	R2,R3		; after the first bit, we are signed
	LSR	1,R1
	LSR	1,R2
	BZ	divu_record_result
	;
	CMP	R1,R0
	SUB.GE	R1,R0
	OR.GE	R2,R3
	LSR	1,R1
	LSR	1,R2
	BZ	divu_record_result
	;
	CMP	R1,R0
	SUB.GE	R1,R0
	OR.GE	R2,R3
	LSR	1,R1
	LSR	1,R2
	BZ	divu_record_result
	;
	CMP	R1,R0
	SUB.GE	R1,R0
	OR.GE	R2,R3
	LSR	1,R1
	LSR	1,R2
	BNZ	divu_next_loop

divu_record_result:
	MOV	R0,R1
	MOV	R3,R0
	LOD	(SP),R2
	LOD	1(SP),R3
	ADD	2,SP
	JMP	R2

