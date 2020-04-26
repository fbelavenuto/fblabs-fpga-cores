;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Filename:	lodsto.S
;
; Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
;
; Purpose:	A quick test of whether or not we can execute loads and
;		stores.  The test does not report success or failure, so
;		you will need to observe it in a simulator to know if it
;		worked or didn't.
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
	LDI	$2,R2
	LOD	peripheral_memory_address(PC),R0
	LOD	$enable_all_interrupts_const(PC),R1
	STO	R1,(R0)
	LDI	infloop(PC),R0
infloop:
	MOV	R0,PC
	HALT			; We should never get here.
peripheral_memory_address
	WORD	0xc0000000
enable_all_interrupts_const
	WORD	0x8001ffff

	
