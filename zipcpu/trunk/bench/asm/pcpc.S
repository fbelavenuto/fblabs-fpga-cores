;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Filename:	pcpc.S
;
; Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
;
; Purpose:	A quick test of whether or not the busy command works.
;		The test does not report success or failure, so you will need
;		to observe it in a simulator to know if it worked or not.
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
	LDI	$1,R0
	MOV	$1(R0),R1
	MOV	$2(R0),R2
	MOV	$3(R0),R3
	MOV	$4(R0),R4
	MOV	$5(R0),R5
	MOV	$6(R0),R6
	MOV	$7(R0),R7
	MOV	$8(R0),R8
	MOV	$9(R0),R9
	MOV	$10(R0),R10
	MOV	$11(R0),R11
	MOV	$12(R0),R12
	MOV	$13(R0),R13	; R14 is CC, R15 is PC
	LDI	$0,R0
	BUSY			; This should create an endless loop here
	; MOV	R0,R0
	; MOV	R0,R0
	; MOV	R0,R0		; By this point, the loop should've started
	LDI	$10,R0		; If we ever get here, we've got problems
	ADD	$1(R0),R1
	ADD	$2(R0),R2
	ADD	$3(R0),R3
	MOV	R0,R0
	MOV	R0,R0		; If we ever get here, we've got problems
	HALT
