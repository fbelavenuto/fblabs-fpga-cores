;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Filename:	poptest.s
;
; Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
;
; Purpose:	Testing whether or not the new popcount (POPC) and bit reversal
;		(BREV) operations work by using software to duplicate these
;	instructions and then comparing the software result to the actual
;	harddware result.  As of the first half billion values, this works.
;	(I'm still running on the rest ....)
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
#define	LFSRFILL	0x000001
#define	LFSRTAPS	0x0408b85
master_entry:
	MOV	user_entry(PC),uPC
	MOV	stack(PC),uSP
	;
	RTU
	; 
	HALT

user_entry:
	; LDI	LFSRFILL,R6
	; LDI	LFSRTAPS,R7
	CLR	R6
	LDI	1,R7
	CLR	R8
	CLR	R12

function_test_loop:
	; Pseudorandom number generator
	; LSR	1,R6
	; XOR.C	R7,R6

	; In order number generator
	ADD	R7,R6

	MOV	R6,R0
	ADD	1,R8

	POPC	R0,R4
	BREV	R0,R5

	MOV	2+__HERE__(PC),R1
	BRA	sw_pop_count
	CMP	R0,R4
	ADD.NZ	1,R12
	TRAP.NZ	0

	MOV	R6,R0
	MOV	2+__HERE__(PC),R1
	BRA	sw_reverse_bit_order
	CMP	R0,R5
	ADD.NZ	2,R12
	TRAP.NZ	0x01000

	;	
	; CMP	LFSRFILL,R6
	; TRAP.Z	0
	;
	CMP	0,R6
	TRAP.Z	0

	BRA	function_test_loop


sw_pop_count:
	; On entry, R0 = value of interest
	;		R1 = return address
	; On exit, R0 = result
	;		R1 = return address
	SUB	2,SP
	STO	R1,(SP)		; R1 will be our loop counter
	STO	R2,1(SP)	; R2 will be our accumulator and eventual result
	CLR	R2
sw_pop_count_loop:
	LSR	1,R0
	ADD.C	1,R2
	BZ	sw_pop_count_exit
	BRA	sw_pop_count_loop
sw_pop_count_exit:
	MOV	R2,R0
	LOD	(SP),R1
	LOD	1(SP),R2
	ADD	2,SP
	JMP	R1


	
sw_reverse_bit_order:
	; On entry, R0 = value of interest
	;		R1 = return address
	; On exit, R0 = result
	;		R1 = return address
	SUB	2,SP
	STO	R1,(SP)		; R1 will be our loop counter
	STO	R2,1(SP)	; R2 will be our accumulator and eventual result
	LDI	32,R1
	CLR	R2
reverse_bit_order_loop:
	LSL	1,R2
	LSR	1,R0
	OR.C	1,R2
	SUB	1,R1
	BZ	reverse_bit_order_exit
	BRA	reverse_bit_order_loop
reverse_bit_order_exit:
	MOV	R2,R0
	LOD	(SP),R1
	LOD	1(SP),R2
	ADD	2,SP
	JMP	R1


	fill	512,0
stack:	// Must point to a valid word initially
	word	0
