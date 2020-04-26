;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Filename:	mpyu.S
;
; Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
;
; Purpose:	Zip assembly file for running doing an unsigned 32x32 bit
;		multiply..
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
mpy32u:	; unsigned R0 * unsigned R1 -> unsigned R0:R1, R2 = rtn addr (on stack)
	SUB	3,SP
	STO	R2,(SP)
	STO	R3,1(SP)
	STO	R4,2(SP)
	;
	MOV	R0,R2
	MPYU	R1,R2	; R2 = Low order bits, low(R0) * low(R1)
	MOV	R0,R3
	LSR	16,R3	; Put high order bits in lower half of R3
	MPYU	R1,R3	; R3 = Mid order bits, high(R0) * low(R1)
	LSR	16,R1	; R1 = High order bits of R1, being done w/ low order
	MOV	R1,R4	; 
	MPYU	R0,R4	; R4 = Mid order bits, low(R0) * high(R1)
	LSR	16,R0
	MPYU	R1,R0	; R0 = High order bits, high(R0) * high(R1)
	ADD	R3,R4	; R4 = sum of mid order bits
	ADD.C	0x010000,R0	; Add in the carry (if it happened)
	MOV	R4,R3	
	LSR	16,R3
	ADD	R3,R0	; R0 = high order bits plus high order mid-bits	
	LSL	16,R4
	ADD	R4,R2	; R2 = low order bits plus low order mid-bits
	ADD.C	1,R0	; Add in the carry to R0 (if it happened)
	MOV	R2,R1	; Place low order bits into R1
	;
	LOD	(SP),R2
	LOD	1(SP),R3
	LOD	2(SP),R4
	ADD	3,SP
	JMP	R2

