;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Filename:	sys.i
;
; Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
;
; Purpose:	This is the beginnings of a system wide header file for the
;		Zip System.   It describes and declares the peripherals
;		that will the be used and referenced by the assembly files.
;
; Status:	As of August, 2015, I have no confidence that the preprocessor
;		can properly include this file.  It certainly cannot handle
;		macros (yet).
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
	sys.bus		equ	0xc0000000
	sys.breaken	equ	0x080
	sys.step	equ	0x040
	sys.gie		equ	0x020
	sys.sleep	equ	0x010
	sys.ccv		equ	0x008
	sys.ccn		equ	0x004
	sys.ccc		equ	0x002
	sys.ccz		equ	0x001
	sys.bus.pic	equ	0x000
	sys.bus.wdt	equ	0x001
	sys.bus.cache	equ	0x002
	sys.bus.ctrpic	equ	0x003
	sys.bus.tma	equ	0x004
	sys.bus.tmb	equ	0x005
	sys.bus.tmc	equ	0x006



; Define the location(s) of our peripherals,
#define	sys.base	0xc0000000
#define	sys.cache.base	0xc0100000
#struct sys
	pic
	wdt
	cache
	ctrpic
	tma
	tmb
	tmc
	jiffies
	mtask
	mstl
	mpstl
	mastl
	utask
	ustl
	upstl
	uastl
#endstruct
; and their associated interrupt vectors ...
#define	CACHEINT	0x01
#define	JIFFYINT	0x02	;
#define	TMCINT		0x04	; 
#define	TMBINT		0x08	; 
#define	TMAINT		0x10	; 
#define	CTRPICINT	0x20	; The aux interrupt controller
; Masks to send to enable those same vectors
#define	CACHEINTEN	0x80010000
#define	JIFFYINTEN	0x80020000
#define	TMCINTEN	0x80040000
#define	TMBINTEN	0x80080000
#define	TMAINTEN	0x80100000
#define	CTRPICEN	0x80200000
; And similar masks to disable them
#define	CACHEINTDIS	0x00010000
#define	JIFFYINTDIS	0x00020000
#define	TMCINTDIS	0x00040000
#define	TMBINTDIS	0x00080000
#define	TMAINTDIS	0x00100000
#define	CTRPICDIS	0x00200000

; Define our condition code bits
#define	CCZ	0x001
#define	CCC	0x002
#define	CCN	0x004
#define	CCV	0x008
#define	CCSLEEP	0x010
#define	CCGIE	0x020
#define	CCSTEP	0x040
#define	CCUBRK	0x080

; Now, some macros
#define	PUSH(RG,SP)	SUB 1,SP		\
			STO RG,1(SP)
#define	POP(RG,SP)	LOD 1(SP),RG		\
			ADD 1,SP
#define	FJSR(LBL,RG)	MOV __here__+2(PC),RG	\
			BRA LBL
#define	FRET(RG)	MOV RG,PC
#define	JSR(LBL,RG)	SUB 1,SP		\
			MOV __here__+3(PC),RG	\
			STO RG,1(SP)		\
			BRA LBL			\
			ADD 1,SP

#define	RET		LOD 1(SP),PC
#define	SAVE_USER_CONTEXT(DA,DB,DC,DD,AR)	\
			MOV -15(uSP),AR		\
			MOV	uR0,DA		\
			MOV	uR1,DB		\
			MOV	uR2,DC		\
			MOV	uR3,DD		\
			STO	DA,(AR)		\
			STO	DB,1(AR)	\
			STO	DC,2(AR)	\
			STO	DD,3(AR)	\
			MOV	uR4,DA		\
			MOV	uR5,DB		\
			MOV	uR6,DC		\
			MOV	uR7,DD		\
			STO	DA,4(AR)	\
			STO	DB,5(AR)	\
			STO	DC,6(AR)	\
			STO	DD,7(AR)	\
			MOV	uR8,DA		\
			MOV	uR9,DB		\
			MOV	uR10,DC		\
			MOV	uR11,DD		\
			STO	DA,8(AR)	\
			STO	DB,9(AR)	\
			STO	DC,10(AR)	\
			STO	DD,11(AR)	\
			MOV	uR12,DA		\
			MOV	uCC,DC		\
			MOV	uPC,DD		\
			STO	DA,12(AR)	\
			STO	DC,13(AR)	\
			STO	DD,14(AR)
#define	RESTORE_USER_CONTEXT(DA,DB,DC,DD,AR)	\
			LOD	(AR),DA		\
			LOD	1(AR),DB	\
			LOD	2(AR),DC	\
			LOD	3(AR),DD	\
			MOV	DA,uR0		\
			MOV	DB,uR1		\
			MOV	DC,uR2		\
			MOV	DD,uR3		\
			LOD	4(AR),DA	\
			LOD	5(AR),DB	\
			LOD	6(AR),DC	\
			LOD	7(AR),DD	\
			MOV	DA,uR4		\
			MOV	DB,uR5		\
			MOV	DC,uR6		\
			MOV	DD,uR7		\
			LOD	8(AR),DA	\
			LOD	9(AR),DB	\
			LOD	10(AR),DC	\
			LOD	11(AR),DD	\
			MOV	DA,uR8		\
			MOV	DB,uR9		\
			MOV	DC,uR10		\
			MOV	DD,uR11		\
			LOD	12(AR),DA	\
			LOD	13(AR),DB	\
			LOD	14(AR),DC	\
			MOV	DA,uR12		\
			MOV	DB,uCC		\
			MOV	DC,uPC		\
			MOV	15(AR),uSP
#define	READ_USER_TRAP(RG)			\
			MOV	uCC,RG		\
			AND	-256,RG
