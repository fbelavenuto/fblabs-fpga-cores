;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Filename:	mpy32s.S
;
; Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
;
; Purpose:	Zip assembly file for running a 32-bit by 32-bit signed
;		multiply.  It works by adjusting the sign of the 32x32-bit
;		unsigned multiply.
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
; We could build mul32s (32-bit signed multiply) as 
;
;	R0 - incoming value to be multiplied
;	R1 - Second multiplicand
;	R2 - Comes in as scratch
;	R3 - used as scratch internally
mpy32s:
	ADD	2,SP
	STO	R2,(SP)
	STO	R3,2(SP)
	;
	CLR	R3		; Keep track of resulting sign in R2
	TST	-1,R0		; Is R0 negative?
	XOR.LT	1,R3		; If so, resulting sign will be negative, and
	NEG.NZ	R0		; then we negate R0 (R0 = ABS(R0))
	TST	-1,R1		; Is R1 negative?
	XOR.LT	1,R3		; If so, result will be opposite sign of before
	NEG.LT	R1		; Now we get R1=ABS(R1)

	; JSR mpy32u	
	MOV	__HERE__+2(PC),R2	; Do our unsigned multiply
	BRA	mpy32u
	;
	TST	-1,R3		; Check resulting sign
	BZ	ret_mul32s	; If positive, do nothing more
	NOT	R0		; If negative, negate the result
	NOT	R1
	ADD	$1,R1
	ADD.C	$1,R0
ret_mul32s:
	LOD	(SP),R2
	LOD	2(SP),R3
	ADD	2,SP
	JMP	R2

