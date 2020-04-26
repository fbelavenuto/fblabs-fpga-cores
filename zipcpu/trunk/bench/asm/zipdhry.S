;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Filename:	zipdhry.S
;
; Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
;
; Purpose:	Zip assembly file for running the Dhrystone benchmark in the
;		Zip CPU.
;
;	To calculate a DMIPS value, take the value of R0 upon completion.  This
;	is the number of clock ticks used from start to finish (i.e., from
;	entrance into user mode to the return to supervisor mode).  Let
;	CLKSPD be your clock speed in Hz.  Then:
;
;	DMIPS = (CLKSPD*NRUNS/R0) / 1757;
;
;	For my tests, CLKSPD = 100e6 Hz (100 MHz), NRUNS = 512.  Thus,
;
;	DMIPS = (100e6 * 512) / R0 / 1757
;
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
// Under Verilator:
//	DMIPS:		30.3	100 MHz	(sim)	0.29	// Initial baseline
//	DMIPS:		37.5	100 MHz	(sim)	0.38	// 20151017
//	DMIPS:		38.0	100 MHz	(sim)	0.38	// 20151211 (new ISA)
//	DMIPS:		40.5	100 MHz	(sim)	0.41	// 20151212 (H/W DIV)
//	DMIPS:		 8.2	100 MHz (sim)	0.08	// 20151104--!pipelined
//	DMIPS:		60.1	100 MHz (sim)	0.60	// 20151215 (New PF)
//	DMIPS:		60.0	100 MHz (sim)	0.60	// 20151226 (BugFix)
// On real hardware:
//	DMIPS:		24.7	100 MHz (basys)	0.25	// Initial baseline
//	DMIPS:		30.6	100 MHz (basys)	0.31	// 20151017
//	DMIPS:		48.4	100 MHz (basys)	0.48	// 20151227 (New pf/ISA)
//
// (And, under Verilator, if the cache holds the entire 4kW program: 55.1 DMIPS)
//
//
//   with no loop unrolling nor function inlining
//	DMIPS:		24.3	100 MHz (sim)	0.24
//   with packed strings
//	DMIPS:		35.6	100 MHz (sim)	0.36
//
// For comparison:
//	uBlaze:		230	177 MHz		1.3
//	LEON3					1.4
//	NiOS II:	218	185 MHz		1.16
//	OpenRisk	250	250 MHz		1.00
//	LM32					1.14
//	ZPU		2.6	 50 MHz		0.05
//

// Some #def's to control compilation.
//
// SKIP_SHORT_CIRCUITS determines whether or not we do internal testing and
// jump to a BUSY instruction on failure for the debugger to pick up.  Skip
// this for valid testing.  Enable it and see whether or not zipdhry dies mid
// process--if it down, you got there--so fix it.
//
#define	SKIP_SHORT_CIRCUITS
//
//
//
// NO_INLINE controls whether or not we inline certain functions.  If you 
// define this, nothing will be inlined.
//
// I recommend not setting this define.
//
// #define	NO_INLINE
//
//
//
// NO_LOOP_UNROLLING controls loop unrolling.  The default is to unroll loops
// by a factor of 4x.  By defining this, all loop unrolling is removed.  (Well,
// except the pipelined strcpy and strcmp below--those loops are automatically
// unrolled as part of being piped.  Undefine those as well and all loops will
// be effectively unrolled.
//
// I recommend not setting this define.
//
// #define	NO_LOOP_UNROLLING
//
//
//
// After building this whole thing and putting it together, I discovered another
// means I could use of generating a return statement.  In this case, instead
// of LOD -1(SP),PC, I would load the return PC from the stack as part of the
// pipelined memory operations, adjust the stack pointer, and jump to the 
// register address.  It saves clocks because it uses the pipelined memory
// operation, but other than that it suffers the same number of stalls.
//
// Fast returns used to be controlled by a #define.  This has been removed,
// and all returns are "fast" by default.
//
//
//
//
//
// SKIP_DIVIDE controlls whether or not we want to calculate the speed of
// our processor assuming we had a divide instruction.  If you skip the
// divide, it will be as though you had such an instruction.  Otherwise,
// leave it in and the test bench will measure how long it takes to run
// while including the divide emulation.
//
// I recommend leaving this undefined, for a more accurate measure.
//
// #define	SKIP_DIVIDE	// 0xace17/0x50f37 vs 0xbd817/0x57d37
//
// Thus a divide instruction might raise our score from 37.5 to 41.1, or
// from 81 to 87.8--depending on whether or not the cache is loaded or not.
//
//
//
//
// HARDWARE_DIVIDE is appropriate when the hardware has a divide instruction,
// as it will use this divide instruction for the one time a divide is needed.
// 
// I recommended setting this value ... IF the hardware has the divide
// instruction built in.
//
#define	HARDWARE_DIVIDE
//
//
// PIPELINED_STRCPY and PIPELINED_STRCMP both have to do with whether or not
// the memory accesses of each of these "library" functions are pipelined.
// As you may recall, the Zip CPU allows you to pipeline memory accesses
// that are all done with the same condition, and that all reference either
// the same or increasing addresses.  These one-clock memory access instructions
// are ridiculously fast (when available), and we would be foolish not to use
// them.  These two defines modify the library functions to use this mode
// and to capitalize upon it as much as possible.
//
// I recommend setting these.
//
#define	PIPELINED_STRCPY
#define	PIPELINED_STRCMP
//
//
	dev.scope.cpu	equ	0x0120
	sys.ctr.mtask	equ	0xc0000008
// int main(int argc, char **argv) {
// 	dhrystone();
// }
// #define	LOAD_ADDRESS	entry+PC
#define	LOAD_ADDRESS	lcl_strcpy+PC
entry:
	; LDI	0x0c000010,R0
	; LDI	dev.scope.cpu,R1
	; STO	R0,(R1)
	;
	MOV	top_of_stack(PC),uSP
	MOV	entry(PC),uR12
	; Store  our tick counter in R1
	LDI	sys.ctr.mtask,R1
	; And start with our counter cleared at zero
	CLR	R0
	STO	R0,(R1)
#ifdef	SUPERVISOR_TASK
	MOV	__HERE__+2(PC),R0
	BRA	dhrystone
#else
	MOV	dhrystone(PC),uPC
	RTU
#endif
	; Read the tick counter back out
	LOD	(R1),R0
	HALT	; Stop the CPU--We're done!!!!!!!

//
// typedef	enum { Ident_1, Ident_2, Ident_3, Ident_4, Ident_5 } test_enum;
// typedef	enum { false, true } bool;

// typedef	int	Arr_1_Dim[50];
// typedef	int	Arr_2_Dim[50][50];
#define	RECSIZE	35
#define	NUMBER_OF_RUNS	(512)
	ptr_comp			equ	0
	discr				equ	1
	variant.var_1.enum_comp		equ	2
	variant.var_1.int_comp		equ	3
	variant.var_1.str_comp		equ	4


//char	*lcl_strcpy(char *d, char *s) {
//	char	*cpd = d, ch;
//
//	do{
//		*cpd++ = ch = *s++;
//	} while(ch);
//
//}
//

#ifdef	PIPELINED_STRCPY
; On entry,
;	R0 = dst
;	R1 = src
;	R2 = return address
lcl_strcpy:
	SUB	4,SP
	STO	R2,(SP)
	STO	R3,1(SP)
	STO	R4,2(SP)
	STO	R5,3(SP)

copy_next_char:
	; R0 = d
	; R1 = s
	; R3 = ch
	LOD	(R1),R2
	LOD	1(R1),R3
	LOD	2(R1),R4
	LOD	3(R1),R5

	CMP	0,R2
	CMP.NZ	0,R3
	CMP.NZ	0,R4
	CMP.NZ	0,R5
	BZ	end_strcpy

	STO	R2,(R0)
	STO	R3,1(R0)
	STO	R4,2(R0)
	STO	R5,3(R0)

	ADD	4,R1
	ADD	4,R0
	BRA copy_next_char

end_strcpy:
	CMP	0,R2
	STO.NZ	R2,(R0)
	CMP.NZ	0,R3
	STO.NZ	R3,1(R0)
	CMP.NZ	0,R4
	STO.NZ	R4,2(R0)
	CMP.NZ	0,R5
	STO.NZ	R5,3(R0)

	LOD	(SP),R2
	LOD	1(SP),R3
	LOD	2(SP),R4
	LOD	3(SP),R5
	ADD	4,SP
#ifndef	SKIP_SHORT_CIRCUITS
	CMP	LOAD_ADDRESS,R2
	HALT.LT
#endif
	JMP	R2

#else
lcl_strcpy:
	; R0 = d
	; R1 = s
	; R3 = ch
copy_next_char:
	SUB	1,SP
	STO	R2,(SP)
#ifdef	NO_LOOP_UNROLLING
	LOD	(R1),R2
	STO	R2,(R0)
	CMP	0,R2
	BZ	lcl_strcpy_end_of_loop
	ADD	1,R0
	ADD	1,R1
	BRA	copy_next_char

#else
	LOD	(R1),R2
	STO	R2,(R0)
	CMP	0,R2
	BZ	lcl_strcpy_end_of_loop
	LOD	1(R1),R2
	STO	R2,1(R0)
	CMP	0,R2
	BZ	lcl_strcpy_end_of_loop
	LOD	2(R1),R2
	STO	R2,2(R0)
	CMP	0,R2
	BZ	lcl_strcpy_end_of_loop
	LOD	3(R1),R2
	STO	R2,3(R0)
	CMP	0,R2
	BZ	lcl_strcpy_end_of_loop
	ADD	4,R0
	ADD	4,R1
	BRA	copy_next_char
#endif
lcl_strcpy_end_of_loop:
	LOD	(SP),R2
	ADD	1,SP
#ifndef	SKIP_SHORT_CIRCUITS
	CMP	LOAD_ADDRESS,R2
	BUSY.LT
#endif
	JMP	R2
#endif

//int	lcl_strcmp(char *s1, char *s2) {
//	char	a, b;
//	do {
//		a = *s1++; b = *s2++;
//	} while((a)&&(a==b));
//
//	return a-b;
//}

#ifdef	PIPELINED_STRCMP
lcl_strcmp:
	SUB	8,SP
	STO	R2,(SP)
	STO	R3,1(SP)
	STO	R4,2(SP)
	STO	R5,3(SP)
	STO	R6,4(SP)
	STO	R7,5(SP)
	STO	R8,6(SP)
	STO	R9,7(SP)

strcmp_top_of_loop:
	LOD	(R0),R2
	LOD	1(R0),R3
	LOD	2(R0),R4
	LOD	3(R0),R5
	;
	LOD	(R1),R6
	LOD	1(R1),R7
	LOD	2(R1),R8
	LOD	3(R1),R9
	;
	;
	CMP	0,R2
	CMP.NZ	0,R3
	CMP.NZ	0,R4
	CMP.NZ	0,R5
	BZ	strcmp_end_loop

	CMP	R2,R6
	CMP.Z	R3,R7
	CMP.Z	R4,R8
	CMP.Z	R5,R9
	BNZ	strcmp_end_loop

	ADD	4,R0
	ADD	4,R1
	BRA	strcmp_top_of_loop

strcmp_end_loop:
	CMP	0,R2
	BZ	final_str_compare
	CMP	R2,R6
	BNZ	final_str_compare

	MOV	R3,R2
	MOV	R7,R6
	CMP	0,R2
	BZ	final_str_compare
	CMP	R2,R6
	BNZ	final_str_compare

	MOV	R4,R2
	MOV	R8,R6
	CMP	0,R2
	BZ	final_str_compare
	CMP	R2,R6
	BNZ	final_str_compare

	MOV	R5,R2
	MOV	R9,R6

final_str_compare:
	SUB	R6,R2
	MOV	R2,R0
	
	LOD	(SP),R2
	LOD	1(SP),R3
	LOD	2(SP),R4
	LOD	3(SP),R5
	LOD	4(SP),R6
	LOD	5(SP),R7
	LOD	6(SP),R8
	LOD	7(SP),R9
	ADD	8,SP
#ifndef	SKIP_SHORT_CIRCUITS
	CMP	LOAD_ADDRESS,R2
	BUSY.LT
#endif
	JMP	R2

#else
lcl_strcmp:
	SUB	2,SP
	STO	R2,(SP)
	STO	R3,1(SP)

strcmp_top_of_loop:
#ifdef	NO_LOOP_UNROLLING
	; LOD	(R0),R2
	; LOD	(R1),R3			; Alternate approach:
	; CMP	R2,R3			;	CMP	0,R2
	; BNZ	strcmp_end_loop		;	BZ	strcmp_end_loop
	; CMP	0,R2			;	CMP	R2,R3
	; BZ	strcmp_end_loop		;	BZ	strcmp_top_of_loop
	; CMP	0,R3			;	
	; BZ	strcmp_end_loop		;	
	; ADD	1,R0
	; ADD	1,R1
	; BRA	strcmp_top_of_loop
	LOD	(R0),R2
	LOD	(R1),R3
	CMP	0,R2
	BZ	strcmp_end_loop
	ADD	1,R0
	ADD	1,R1
	CMP	R2,R3
	BZ	strcmp_top_of_loop
#else
	LOD	(R0),R2
	LOD	(R1),R3
	CMP	0,R2
	BZ	strcmp_end_loop
	CMP	R2,R3
	BNZ	strcmp_end_loop
	LOD	1(R0),R2
	LOD	1(R1),R3
	CMP	0,R2
	BZ	strcmp_end_loop
	CMP	R2,R3
	BNZ	strcmp_end_loop
	LOD	2(R0),R2
	LOD	2(R1),R3
	CMP	0,R2
	BZ	strcmp_end_loop
	CMP	R2,R3
	BNZ	strcmp_end_loop
	LOD	3(R0),R2
	LOD	3(R1),R3
	CMP	0,R2
	BZ	strcmp_end_loop
	CMP	R2,R3
	BNZ	strcmp_end_loop
	ADD	4,R0
	ADD	4,R1
	BRA	strcmp_top_of_loop
#endif

strcmp_end_loop:
	SUB	R3,R2
	MOV	R2,R0

	LOD	(SP),R2
	LOD	1(SP),R3
	ADD	2,SP
#ifndef	SKIP_SHORT_CIRCUITS
	CMP	LOAD_ADDRESS,R2
	BUSY.LT
#endif
	JMP	R2
#endif
	

//test_enum	func_1(char ch_1, char ch_2) {
//	char	lcl_ch_1, lcl_ch_2;
//
//	lcl_ch_1 = ch_1;
//	lcl_ch_2 = lcl_ch_1;
//	if (lcl_ch_2 != ch_2)
//		return 0;
//	else {
//		gbl_ch = lcl_ch_1;
//		return 1;
//	}

#ifdef	NO_INLINE
func_1:
	; On input,
	; R0 = ch_1
	; R1 = ch_2
	; R2 = available
	; On output, R0 is our return value

	SUB	1,SP
	STO	R2,(SP)
	MOV	R0,R2
	CMP	R2,R1
	CLR.NZ	R0
	STO.Z	R2,gbl_ch(R12)
	LDILO.Z	1,R0
	LOD	(SP),R2
	ADD	1,SP
#ifndef	SKIP_SHORT_CIRCUITS
	CMP	LOAD_ADDRESS,R2
	BUSY.LT
#endif
	JMP	R2
#endif

//bool	func_2(char *str_1, char *str_2) {
//	int	lcl_int;
//	char	lcl_ch;
//
//	lcl_int = 2;
//	while(lcl_int <= 2) {
//		if (func_1(str_1[lcl_int], str_2[lcl_int+1])==0) {
//			lcl_ch = 'A';
//			lcl_int ++;
//		}
//	}
//
//	if ((lcl_ch >= 'W')&&(lcl_ch < 'Z'))
//		lcl_int = 7;
//	if (lcl_ch == 'R')
//		return true;
//	else {
//		if (lcl_strcmp(str_1, str_2)>0) {
//			lcl_int += 7;
//			gbl_int = lcl_int;
//		} else
//			return false;
//	}
//}
func_2:
	;
	SUB	6,SP
#ifndef	SKIP_SHORT_CIRCUITS
	CMP	LOAD_ADDRESS,R2
	BUSY.LT
#endif
	STO	R2,(SP)		; SP = 0x08daf
	STO	R3,1(SP)
	STO	R4,2(SP)
	STO	R5,3(SP)
	STO	R6,4(SP)
	STO	R7,5(SP)

	MOV	R0,R3	; R3 = str_1
	MOV	R1,R4	; R4 = str_2
	LDI	2,R5	; R5 = lcl_int
	LDI	'A',R7	; R7 = lcl_ch
func_2_while_loop:
	CMP	2,R5
	BGT	func_2_end_while_loop
func_2_top_while_loop:
	MOV	R3,R6
	ADD	R5,R6

#ifdef	NO_INLINE
	LOD	(R6),R0
	MOV	R4,R6
	ADD	R5,R6
	LOD	1(R6),R1

	MOV	__HERE__+2(PC),R2
	BRA	func_1

	CMP	0,R0
	ADD.Z	1,R5
#ifndef	SKIP_SHORT_CIRCUITS
	BUSY.NZ
#endif
#else
	LOD	(R6),R2
	MOV	R4,R6
	ADD	R5,R6
	LOD	1(R6),R1

	CMP	R2,R1
	STO.Z	R2,gbl_ch(R12)
	LDILO.Z	1,R0

	ADD.NZ	1,R5
#ifndef	SKIP_SHORT_CIRCUITS
	BUSY.Z
#endif
#endif

	CMP	3,R5
#ifndef	SKIP_SHORT_CIRCUITS
	BUSY.LT
#endif
	BLT	func_2_top_while_loop

func_2_end_while_loop:

	// CMP	'W',R7			// BUT! We know lcl_ch='A'
	// BLT	skip_if			// So we can skip this
	// CMP	'Z',R7			// entire  section
	// LDI.LT	7,R5
	// CMP	'R',R7
	// BNZ alt_if_case
	// LLO.Z	1,R0
	// BRA	func_2_return_and_cleanup
	//	
	MOV	R3,R0
	MOV	R4,R1
	MOV	__HERE__+2(PC),R2
	BRA	lcl_strcmp
	CMP	0,R0
	BGT	func_2_final_then
	CLR	R0
	BRA	func_2_return_and_cleanup
func_2_final_then:
	// ADD	7,R5		; Never read, so useless code
	LDI	1,R0
#ifndef	SKIP_SHORT_CIRCUITS
	BUSY
#endif
func_2_return_and_cleanup:
	
	LOD	(SP),R2
	LOD	1(SP),R3
	LOD	2(SP),R4
	LOD	3(SP),R5
	LOD	4(SP),R6
	LOD	5(SP),R7
	ADD	6,SP
#ifndef	SKIP_SHORT_CIRCUITS
	CMP	LOAD_ADDRESS,R2
	BUSY.LT
#endif
	JMP	R2

//bool	func_3(test_enum a) {
//	test_enum	lcl_enum;
//
//	lcl_enum = a;
//	if (lcl_enum == Ident_3)
//		return true;
//	else
//		return false;
//}

#ifdef	NO_INLINE
func_3:
	; On entry,
	;  R0 = a
	;  R1 - available
	CMP	2,R0
	CLR	R0	; CLR Doesn't set flags
	LDILO.Z	1,R0
#ifndef	SKIP_SHORT_CIRCUITS
	CMP	LOAD_ADDRESS,R1
	BUSY.LT
#endif
	JMP	R1
#endif


// void proc_6(test_enum ev, test_enum *ep) {
//	*ep = ev;
//	if (!func_3(ev))
//		*ep = 3;
//	switch(ev) {
//		case 0:	*ep = 0; break;
//		case 1:
//			if (gbl_int > 100)
//				*ep = 0;
//			else
//				*ep = 3;
//			break;
//		case 2:
//			*ep = 1;
//			break;
//		case 3:
//			break;
//		case 4:
//			*ep = 2;
//	}
//}

proc_6:
	; On entry:
	;	R0 = ev
	;	R1 = ep
	;	R2 = link address
	; Since we call func_3, we have to reserve R0 and R1
	; for other purposes.  Thus
	;	R2 = ev
	;	R3 = ep
	SUB	2,SP
	STO	R2,(SP)
	STO	R3,1(SP)

	MOV	R1,R3
	MOV	R0,R2
	; *ep = ev
	STO	R0,(R1)
#ifndef	SKIP_SHORT_CIRCUITS
	CMP	2,R0
	BUSY.NZ
#endif

#ifdef	NO_INLINE
	; !func_3(ev)
	MOV	__HERE__+2(PC),R1
	BRA	func_3

	TST	-1,R0
	LDI	3,R1
#ifndef	SKIP_SHORT_CIRCUITS
	BUSY.Z
#endif
	STO.Z	R1,(R3)
#else
	CMP	2,R0
	LDI	3,R1
#ifndef	SKIP_SHORT_CIRCUITS
	BUSY.NZ
#endif
	STO.NZ	R1,(R3)
#endif

#ifndef	SKIP_SHORT_CIRCUITS
	CMP	2,R2
	BUSY.NZ
#endif
	CMP	0,R2
	BNZ	proc_6_case_not_zero
#ifndef	SKIP_SHORT_CIRCUITS
	BUSY
#endif
	LDI	0,R1
	STO	R1,(R3)
	BRA	proc_6_end_of_case
proc_6_case_not_zero:
	CMP	1,R2
	BNZ	proc_6_case_not_one
#ifndef	SKIP_SHORT_CIRCUITS
	BUSY
#endif
	LDI	3,R0
	LOD	gbl_int(R12),R1
	CMP	100,R1
	CLR.GT	R0
	STO	R0,(R3)
	BRA	proc_6_end_of_case
proc_6_case_not_one:
	CMP	2,R2
	BNZ	proc_6_case_not_two
	LDI	1,R1				// Executed, if done properly
	STO	R1,(R3)
	BRA	proc_6_end_of_case
proc_6_case_not_two:
#ifndef	SKIP_SHORT_CIRCUITS
	NOOP				;;;;;;;; TODO This fails--needs the NOOP
	BUSY				;;;;;;;; TODO so as not to do the BUSY
#endif
	CMP	4,R2
	BNZ	proc_6_case_not_four
	LDI	2,R1
	STO	R1,(R3)
	// BRA	proc_6_end_of_case
proc_6_case_not_four:
proc_6_end_of_case:
	LOD	(SP),R2
	LOD	1(SP),R3
#ifndef	SKIP_SHORT_CIRCUITS
	CMP	LOAD_ADDRESS,R2		; TODO This fails, even when the address
	BUSY.LT
#endif
	ADD	2,SP
	JMP	R2

// void proc_7(int a, int b, int *c) {
// 	int	lcl;
// 
// 	lcl = a + 2;
// 	*c = b + a;
//}

#ifdef	NO_INLINE
proc_7:
	ADD 2+R0,R1
	STO R1,(R2)

#ifndef	SKIP_SHORT_CIRCUITS
	CMP	LOAD_ADDRESS,R3
	BUSY.LT
#endif
	JMP	R3
#endif

//	int	a[50];
//	int	b[50][50];
//
// void proc_8(Arr_1_Dim a, Arr_2_Dim b, int c, int d) {
//	int	idx, loc;
//
//	loc = c+5;
//	a[loc] = d;
//	a[loc+1] = a[loc];
//	a[loc+30] = loc;
//	for(idx=loc; idx<= loc+1; idx++)
//		b[loc][idx] = loc;
//	b[loc][loc-1] += 1;
//	b[loc+20][loc] = a[loc];
//	gbl_int = 5;
//}
proc_8:
	; R0 = a
	; R1 = b
	; R2 = c
	; R3 = d
	; R4 - unassigned
	; Makes no function/procedure calls, so these can keep
	; R2 = loc = c+5, replaces c
	; R4 = idx
	SUB	3,SP
	STO	R4,(SP)
	STO	R5,1(SP)
	STO	R6,2(SP)

	ADD	5,R2	; loc = c+5
	MOV	R0,R5
	ADD	R2,R5
	STO	R3,(R5)
	STO	R3,1(R5)
	STO	R2,30(R5)
	MOV	R2,R5
	MPYU	50,R5	; R5 = 50 * R2 = 50 * loc
	ADD	R1,R5	; R5 = &b[loc][0]
	MOV	R5,R6	; R6 = &b[loc][0]
	ADD	R2,R5	; R5 = &b[loc][loc]
	MOV	R2,R4	; R4 = loc = index
proc_8_top_of_loop:
	CMP	1(R2),R4
	BGT	proc_8_end_of_loop
proc_8_loop_after_condition:
	STO	R2,(R5)
	ADD	1,R5
	ADD	1,R4
	CMP	2(R2),R4
	BLT	proc_8_loop_after_condition
proc_8_end_of_loop:

	; b[loc][loc-1] += 1
	ADD	R2,R6		; R6 = &b[loc][loc]
	LOD	-1(R6),R5
	ADD	1,R5
	STO	R5,-1(R6)
	; b[loc+20][loc] = a[loc]
	MOV	R0,R4
	ADD	R2,R4
	LOD	(R4),R3
	STO	R3,20*50(R6)
	LDI	5,R3
	STO	R3,gbl_int(R12)
	
	LOD	(SP),R4
	LOD	1(SP),R5
	LOD	2(SP),R6
	ADD	3,SP
#ifndef	SKIP_SHORT_CIRCUITS
	CMP	LOAD_ADDRESS,R4
	BUSY.LT
#endif
	JMP	R4

// void proc_5(void) {
// 	gbl_ch = 'A';
// 	gbl_bool = false;
//}
#ifdef	NO_INLINE
proc_5:
	SUB	1,SP
	STO	R0,(SP)
	;
	LDI	'A',R0
	STO	R0,gbl_ch(R12)
	CLR	R0
	STO	R0,gbl_bool(R12)
	;
	LOD	(SP),R0
	ADD	1,SP
	JMP	R0
#endif

// void proc_4(void) {
//	bool	lcl_bool;
//	lcl_bool = (gbl_ch == 'A');
//	gbl_ch_2 = 'B';
// }
#ifdef	NO_INLINE
proc_4:
	//
	; LDI	GBL,R12	// Already in R12
	; Setting lcl_bool is irrelevant, so the optimizer should remove it.
	; R0 doesn't need to be saved, since it's already trashed by the
	; subroutine call.
	;
	; LOD	gbl_ch(R12),R0
	; CLR	R1
	; CMP	'A',R0
	; ADD.Z	1,R1
	;
	SUB	1,SP
	STO	R0,(SP)
	;
	LDI	'B',R0
	STO	R0,gbl_ch_2(R12)
	;
	LOD	(SP),R0
	ADD	1,SP
	JMP	R0
#endif

// void	proc_3(RECP *a) {
//	if (gbl_ptr != NULL)
//		*a = gbl_ptr->ptr_comp;
//	proc_7(10,gbl_int, &gbl_ptr->variant.var_1.int_comp); // ??
//}
proc_3:
	SUB	3,SP
	STO	R1,(SP)
	STO	R2,1(SP)
	STO	R3,2(SP)
	;
	LOD	gbl_ptr(R12),R2
	TST	-1,R2
#ifndef	SKIP_SHORT_CIRCUITS
	BUSY.Z
#endif
	LOD.NZ	ptr_comp(R2),R3
	STO.NZ	R3,(R0)
#ifdef	NO_INLINE
	LDI	10,R0
	LOD	gbl_int(R12),R1
	MOV	variant.var_1.int_comp(R2),R2
	MOV	__HERE__+2(PC),R3
	BRA	proc_7
#else
	LOD	gbl_int(R12),R1
	ADD	 12,R1
	STO	 R1,variant.var_1.int_comp(R2)
#endif
	;
	LOD	(SP),R1
	LOD	1(SP),R2
	LOD	2(SP),R3
	ADD	3,SP
#ifndef	SKIP_SHORT_CIRCUITS
	CMP	LOAD_ADDRESS,R1
	BUSY.LT
#endif
	JMP	R1

// void	proc_2(int *a) {
// 	int		lcl_int;
// 	test_enum	lcl_enum;
// 
// 	lcl_int = *a + 10;
// 	do {
// 		if (gbl_ch == 'A') {
// 			lcl_int -= 1;
// 			*a = lcl_int - gbl_int;
// 			lcl_enum = Ident_1;
// 		}
// 	} while(lcl_enum != Ident_1);
//}
proc_2:
	SUB	6,SP
	STO	R1,(SP)
	STO	R2,1(SP)
	STO	R3,2(SP)
	STO	R4,3(SP)
	STO	R5,4(SP)
	STO	R6,5(SP)
	// R1 doesn't need to be stored, it was used in the subroutine
	// call calculation

	LOD	(R0),R1
	MOV	10(R1),R2	; R2 = lcl_int
	LOD	gbl_ch(R12),R4	; R4 = gbl_ch
#ifdef	NO_CHEATING
proc_2_loop:
	CMP	'A',R4
	SUB.Z	1,R2
	LOD.Z	gbl_int(R12),R5	; R5 = gbl_int
	MOV.Z	R2,R6		; R6 = lcl_int
	SUB.Z	R5,R6		; lcl_int - gbl_int
	STO.Z	R6,(R0)		; *a = R6
	CLR.Z	R3		; lcl_enum = 0
// #ifndef	SKIP_SHORT_CIRCUITS
	// BUSY.NZ
// #endif

	TST	-1,R3
// #ifndef	SKIP_SHORT_CIRCUITS
	// BUSY.NZ
// #endif
	BNZ	proc_2_loop
#else
	LOD	gbl_int(R12),R5
	SUB	1(R5),R2
	STO	R2,(R0)
#endif
	;
	LOD	(SP),R1
	LOD	1(SP),R2
	LOD	2(SP),R3
	LOD	3(SP),R4
	LOD	4(SP),R5
	LOD	5(SP),R6
	ADD	6,SP
#ifndef	SKIP_SHORT_CIRCUITS
	CMP	LOAD_ADDRESS,R1
	BUSY.LT
#endif
	JMP	R1

//void	proc_1 (RECP a) {
//	RECP	nxt = a->ptr_comp;
//
//	// structassign(a->ptr_comp, gbl_ptr);
//	*(a->ptr_comp) = *(gbl_ptr);
//
//	a->variant.var_1.int_comp = 5;
//	nxt->variant.var_1.int_comp = a->variant.var_1.int_comp;
//	proc_3(&nxt->ptr_comp);
//
//	if (nxt->discr == 0) {
//		nxt->variant.var_1.int_comp = 6;
//		proc_6(a->variant.var_1.enum_comp, &nxt->variant.var_1.enum_comp);
//		nxt->ptr_comp = gbl_ptr->ptr_comp;
//		proc_7(nxt->variant.var_1.int_comp, 10, &nxt->variant.var_1.int_comp);
//	} else
//		// structassign(a, a->ptr_comp);
//		*a = *(a->ptr_comp);
//}
proc_1:
	SUB	11,SP
	STO	R1,(SP)
	STO	R2,1(SP)
	STO	R3,2(SP)
	STO	R4,3(SP)
	STO	R5,4(SP)
	STO	R6,5(SP)
	STO	R7,6(SP)
	STO	R8,7(SP)
	STO	R9,8(SP)
#ifndef	NO_LOOP_UNROLLING
	STO	R10,9(SP)
	STO	R11,10(SP)
#endif

	; R9 = a
	; R4 = nxt
	; R12 = GBL
	; R13 = SP
	MOV	R0,R9
	LOD	ptr_comp(R9),R4
#ifndef	SKIP_SHORT_CIRCUITS
	TST	-1,R4		; R4 = 0x100e9f
	BUSY.Z
	CMP	PC,R9		; R9 = 0x100ec2
	BUSY.LT
#endif
	MOV	R9,R6
	LOD	gbl_ptr(R12),R7	; (0x100a04) -> 0x100ec2
	; BUSY			; R7 = 0x0100ec2

#ifndef	SKIP_SHORT_CIRCUITS
	LOD	variant.var_1.enum_comp(R7), R0
	CMP	2,R0		; R0 = 0
	BUSY.NZ			; TODO Fails here
#endif

#ifdef	NO_LOOP_UNROLLING
	LDI	35,R5
proc_1_assign_loop_1:
	LOD	(R6),R8
	ADD	1,R6
	STO	R8,(R7)
	ADD	1,R7
	SUB	1,R5
	BNZ	proc_1_assign_loop_1;
#else

	; R2 is available
	; R3 is available

	LDI	34,R5
proc_1_assign_loop_1:
	LOD	(R6),R8
	LOD	1(R6),R10
	LOD	2(R6),R11
	LOD	3(R6),R2
	LOD	4(R6),R3
	ADD	5,R6
	SUB	5,R5
	STO	R8,(R7)
	STO	R10,1(R7)
	STO	R11,2(R7)
	STO	R2,3(R7)
	STO	R3,4(R7)
	BLT	proc_1_assign_loop_1_end
	ADD	5,R7
	; BNZ	proc_1_assign_loop_1;
	BRA	proc_1_assign_loop_1
proc_1_assign_loop_1_end:
	; Loop length is fixed, nothing to test here
#endif

#ifndef	SKIP_SHORT_CIRCUITS
	LOD	gbl_ptr(R12),R2
	TST	-1,R2
	BUSY.Z
	;
	LOD	variant.var_1.enum_comp(R9), R0
	CMP	2,R0
	BUSY.NZ	
#endif

	LDI	5,R5
	STO	R5,variant.var_1.int_comp(R9)
	STO	R5,variant.var_1.int_comp(R4)
	MOV	ptr_comp(R4),R0			; R4 = 0x8e41, ptr_comp(R4)=R4
	MOV	__HERE__+2(PC),R1
	BRA	proc_3		; Uses R0 and R1

	LOD	discr(R4),R5
	CMP	0,R5
	BNZ	proc_1_last_struct_assign
	; This is the juncture that is "supposed" to be taken
	LDI	6,R5

	STO	R5,variant.var_1.int_comp(R4)
	LOD	variant.var_1.enum_comp(R9), R0
#ifndef	SKIP_SHORT_CIRCUITS
	CMP	2,R0
	BUSY.NZ
#endif
	MOV	variant.var_1.enum_comp+R4, R1
	MOV	__HERE__+2(PC),R2
	BRA	proc_6
	;
	LOD	gbl_ptr(R12),R5
	LOD	ptr_comp(R5),R5	
	STO	R5,ptr_comp(R4)
	;
#ifdef	NO_INLINE
	LOD	variant.var_1.int_comp(R4),R0
	LDI	10,R1
	MOV	variant.var_1.int_comp(R4),R2
	MOV	proc_1_return_closeout(PC),R3
	BRA	proc_7
#else
	LOD	variant.var_1.int_comp(R4),R0
	ADD	12,R0
	STO	R0,variant.var_1.int_comp(R4)
	BRA	proc_1_return_closeout
#endif
	;
proc_1_last_struct_assign:
#ifndef	SKIP_SHORT_CIRCUITS
	BUSY
#endif
	LDI	35,R4
	MOV	R2,R5
	LOD	gbl_ptr(R12),R6
proc_1_assign_loop_2:
	LOD	(R6),R8
	STO	R8,(R7)
	ADD	1,R6
	ADD	1,R7
	SUB	1,R5
	BNZ	proc_1_assign_loop_2
	//
proc_1_return_closeout:
	//
	LOD	(SP),R1
	LOD	1(SP),R2
	LOD	2(SP),R3
	LOD	3(SP),R4
	LOD	4(SP),R5
	LOD	5(SP),R6
	LOD	6(SP),R7
	LOD	7(SP),R8
	LOD	8(SP),R9
#ifndef	NO_LOOP_UNROLLING
	LOD	9(SP),R10
	LOD	10(SP),R11
#endif
	ADD	11,SP
#ifndef	SKIP_SHORT_CIRCUITS
	CMP	LOAD_ADDRESS,R1
	BUSY.LT
#endif
	JMP	R1		// Jumps to wrong address ??

// void dhrystone(void) {
//	int	lcl_int_1, lcl_int_2, lcl_int_3, index, number_of_runs = 500;
//	test_enum	lcl_enum;
//	char	lcl_str_1[30], lcl_str_2[30], ch_index;
//	REC_T	a, b, *nxt = &a;
//
//	gbl_ptr = &b;
//	gbl_ptr->ptr_comp = nxt;
//	gbl_ptr->variant.var_1.enum_comp = 2;
//	gbl_ptr->variant.var_1.int_comp = 40;
//	lcl_strcpy(gbl_ptr->variant.var_1.str_comp, "DHRYSTONE PROGRAM, SOME STRING");
//	lcl_strcpy(lcl_str_1, "DHRYSTONE PROGRAM, 1\'ST STRING");
//
//	gbl_arr_2[8][7] = 10;
//
//	for(index=0; index < number_of_runs; index++) {
//		proc_5();
//		proc_4();
//		lcl_int_1 = 2;
//		lcl_int_2 = 3;
//		lcl_strcpy(lcl_str_2, "DHRYSTONE PROGRAM, 2\'ND STRING");
//		lcl_enum = Ident_2;
//		gbl_bool = !func_2(lcl_str_1, lcl_str_2);
//		while(lcl_int_1 < lcl_int_2) {
//			lcl_int_3 = 5 * lcl_int_1 - lcl_int_2;
//			proc_7(lcl_int_1, lcl_int_2, &lcl_int_3);
//			lcl_int_1 += 1;
//		}
//
//		proc_8(gbl_arr_1, gbl_arr_2, lcl_int_1, lcl_int_3);
//		proc_1(gbl_ptr);
//
//		for(ch_index='A'; ch_index <= gbl_ch_2; ch_index++) {
//			if (lcl_enum == func_1(ch_index, 'C')) {
//				// Then not executed??
//				proc_6(0, &lcl_enum);
//				lcl_strcpy(lcl_str_2, "DHRYSTONE PROGRAM, 3\'RD STRING");
//				lcl_int_2 = index;
//				gbl_int = index;
//			}
//		}
//
//		lcl_int_2 = lcl_int_2 * lcl_int_1;
//		lcl_int_1 = lcl_int_2 / lcl_int_3;
//		lcl_int_2 = 7 * ( lcl_int_2 - lcl_int_3) - lcl_int_1;
//		proc_2(&lcl_int_1);
//	}
//}

dhrystone:
#ifdef	SUPERVISOR_TASK
	SUB	12+RECSIZE+RECSIZE+30+30+3,SP
	; Leave a space on the top of the stack for calling 
	; subroutines.
	STO	R0,(SP)
	STO	R1,1(SP)
	STO	R2,2(SP)
	STO	R3,3(SP)
	STO	R4,4(SP)
	STO	R5,5(SP)
	STO	R6,6(SP)
	STO	R7,7(SP)
	STO	R8,8(SP)
	STO	R9,9(SP)
	STO	R10,10(SP)
	STO	R11,11(SP)
	lcl_int_1	equ	12			; plus SP
#else
	lcl_int_1	equ	2			; plus SP
	SUB	2+RECSIZE+RECSIZE+30+30+3,SP
#endif
	// 12 is the global variable pointer
	// 13 is our stack
	// 14 is our condition code register
	// 15 is the program counter
	;
	lcl_int_3	equ	lcl_int_1+1		; plus SP
	lcl_enum	equ	lcl_int_3+1		; plus SP
	lcl_str_1	equ	lcl_enum+1		; plus SP
	lcl_str_2	equ	lcl_str_1+30		; plus SP
	rec_a		equ	lcl_str_2+30		; plus SP
	rec_b		equ	rec_a+RECSIZE		; plus SP
	
//	int	lcl_int_1, lcl_int_2, lcl_int_3, index, number_of_runs = 500;
//	test_enum	lcl_enum;
//	char	lcl_str_1[30], lcl_str_2[30], ch_index;
//	REC_T	a, b, *nxt = &a;
//
//	gbl_ptr = &b;
	MOV	rec_b(SP),R0		; R0 = &b
	STO	R0,gbl_ptr(PC)
//	gbl_ptr->ptr_comp = nxt;
	MOV	rec_a(SP),R1		; R1 = &a = nxt
	STO	R1,ptr_comp(R0)		; gbp_ptr->ptr.comp=b->ptr.comp=R1=nxt
//	gbl_ptr->variant.var_1.enum_comp = 2;
	LDI	2,R2
	STO	R2,variant.var_1.enum_comp(R0)
//	gbl_ptr->variant.var_1.int_comp = 40;
	LDI	40,R2
	STO	R2,variant.var_1.int_comp(R0)
//	lcl_strcpy(gbl_ptr->variant.var_1.str_comp, "DHRYSTONE PROGRAM, SOME STRING");
	MOV	variant.var_1.str_comp(R0),R0
	MOV	some_string(PC),R1
	MOV	__HERE__+2(PC),R2
	BRA	lcl_strcpy

//	lcl_strcpy(lcl_str_1, "DHRYSTONE PROGRAM, 1\'ST STRING");
	MOV	lcl_str_1(SP),R0
	MOV	first_string(PC),R1
	MOV	__HERE__+2(PC),R2
	BRA	lcl_strcpy

//	gbl_arr_2[8][7] = 10;
	LDI	10,R0
	STO	R0,8*50+7+gbl_arr_2(R12)
//
//	for(index=0; index < number_of_runs; index++) {
	; Let R11 be our index
	CLR	R11
dhrystone_main_loop:
	;; Start of Dhrystone main loop
	; proc_5();
#ifdef	NO_INLINE
	MOV	__HERE__+2(PC),R0
	BRA	proc_5
#else
	LDI	'A',R0
	STO	R0,gbl_ch(R12)
	CLR	R0
	STO	R0,gbl_bool(R12)
#endif
	; proc_4();
#ifdef	NO_INLINE
	MOV	__HERE__+2(PC),R0
	BRA	proc_4
#else
	LDI	'B',R0
	STO	R0,gbl_ch_2(R12)
#endif
//		lcl_int_1 = 2;
	LDI	2,R5
	STO	R5,lcl_int_1(SP)
//		lcl_int_2 = 3;
	LDI	3,R6
//		lcl_strcpy(lcl_str_2, "DHRYSTONE PROGRAM, 2\'ND STRING");
	MOV	lcl_str_2(SP),R0
	MOV	second_string(PC),R1
	MOV	__HERE__+2(PC),R2
	BRA	lcl_strcpy
//		lcl_enum = Ident_2;
	LDI	2,R0
	STO	R0,lcl_enum(SP)
//		gbl_bool = !func_2(lcl_str_1, lcl_str_2);
	MOV	lcl_str_1(SP),R0
	MOV	lcl_str_2(SP),R1
	MOV	__HERE__+2(PC),R2
	BRA	func_2
	CLR	R1
	TST	-1,R0
	LDILO.Z	1,R1
	STO	R1,gbl_bool(PC)

//		while(lcl_int_1 < lcl_int_2) {
	; R5 = lcl_int_1 = 2 on entry
	; R6 = lcl_int_2 = 3 on entry, so no entry test is required
	LOD	lcl_int_1(SP),R5
	// The 'while' comparison
	CMP	R6,R5
	BGE	dhrystone_end_while_loop
dhrystone_while_loop:
//			lcl_int_3 = 5 * lcl_int_1 - lcl_int_2;
	MOV	R5,R7
	LDI	5,R0
	MPYS	R0,R7
	SUB	R6,R7
	STO	R7,lcl_int_3(SP)
#ifndef	SKIP_SHORT_CIRCUITS
	CMP	7,R7
	BUSY.NZ
#endif
//			proc_7(lcl_int_1, lcl_int_2, &lcl_int_3);
#ifdef	NO_INLINE
	MOV	R5,R0
	MOV	R6,R1
	MOV	lcl_int_3(SP),R2
	MOV	__HERE__+2(PC),R3
	BRA	proc_7
#else
	MOV	R6,R1
	ADD	2+R5,R1
	STO	R1,lcl_int_3(SP)
#endif
//			lcl_int_1 += 1;
	LOD	lcl_int_1(SP),R5
	ADD	1,R5
	STO	R5,lcl_int_1(SP)
;
	; BRA	dhrystone_while_loop	; We'll unroll the loop, and put an
	CMP	R6,R5			; additional comparison at the bottom
	BLT	dhrystone_while_loop
dhrystone_end_while_loop:
//		}
//
#ifndef	SKIP_SHORT_CIRCUITS
	LOD	lcl_int_1(SP),R0
	CMP	3,R0
	BUSY.NZ
	CMP	3,R6
	BUSY.NZ	
	LOD	lcl_int_3(SP),R0
	CMP	7,R0
	BUSY.NZ
#endif
//		proc_8(gbl_arr_1, gbl_arr_2, lcl_int_1, lcl_int_3);
	MOV	gbl_arr_1(PC),R0
	MOV	gbl_arr_2(PC),R1
	MOV	R5,R2
	MOV	R6,R3
	MOV	__HERE__+2(PC),R4
	BRA	proc_8
//		proc_1(gbl_ptr);
	LOD	gbl_ptr(PC),R0
#ifndef	SKIP_SHORT_CIRCUITS
	LOD	variant.var_1.enum_comp(R0), R1
	CMP	2,R1		; R0 = 0
	BUSY.NZ			; TODO Fails here
#endif
	MOV	__HERE__+2(PC),R1
	BRA	proc_1
//
//		for(ch_index='A'; ch_index <= gbl_ch_2; ch_index++) {
	LDI	'A',R7
	LOD	gbl_ch_2(SP),R8
	CMP	R7,R8
	BLT	dhrystone_end_of_for_loop
dhrystone_top_of_for_loop:
//			if (lcl_enum == func_1(ch_index, 'C')) {
#ifdef	NO_INLINE
	MOV	R7,R0
	LDI	'C',R1
	MOV	__HERE__+2(PC),R2
	BRA	func_1
#else
	CMP	'C',R7
	CLR.NZ	R0
	STO.Z	R7,gbl_ch(R12)
	LDILO.Z	1,R0
#endif

	; Result is now in R0
	LOD	lcl_enum(SP),R1
	CMP	R0,R1
	BNZ	dhrystone_skip_then_clause
//				// Then not executed??
//				proc_6(0, &lcl_enum);

#ifndef	SKIP_SHORT_CIRCUITS
	BUSY	// Shouldn't ever get here
#endif

	CLR	R0
	MOV	lcl_enum(SP),R1
	MOV	__HERE__+2(PC),R2
	BRA	proc_6
	
//				lcl_strcpy(lcl_str_2, "DHRYSTONE PROGRAM, 3\'RD STRING");
	MOV	lcl_str_2(SP),R0
	MOV	third_string(PC),R1
	MOV	__HERE__+2(PC),R2
	BRA	lcl_strcpy
//				lcl_int_2 = index;
	MOV	R11,R6
//				gbl_int = index;
	STO	R11,gbl_int(PC)
//			}
dhrystone_skip_then_clause:
	ADD	1,R7
	LOD	gbl_ch_2(SP),R8
	CMP	R8,R7
	BGE	dhrystone_top_of_for_loop
dhrystone_end_of_for_loop:
//		}
#ifndef	SKIP_SHORT_CIRCUITS
	LOD	lcl_int_1(SP),R0
	CMP	3,R0
	BUSY.NZ
	CMP	3,R6
	BUSY.NZ
	LOD	lcl_int_3(SP),R0
	CMP	7,R0
	BUSY.NZ
#endif
//
//		lcl_int_2 = lcl_int_2 * lcl_int_1;
	LOD	lcl_int_1(SP),R5
	MPYS	R5,R6	; lcl_int_2 = 
//		lcl_int_1 = lcl_int_2 / lcl_int_3;
#ifdef	HARDWARE_DIVIDE
	LOD	lcl_int_3(SP),R1
	MOV	R6,R0
	DIVS	R1,R0
#else
#ifndef	SKIP_DIVIDE
	MOV	R6,R0
	LOD	lcl_int_3(SP),R1
	MOV	__HERE__+2(PC),R2
	BRA	lib_divs
#else
	LDI	9,R0
#endif
#endif
	STO	R0,lcl_int_1(SP)	;;; TODO FAILS HERE (Watched it fail!)
//		lcl_int_2 = 7 * ( lcl_int_2 - lcl_int_3) - lcl_int_1;
	LOD	lcl_int_3(SP),R2
	SUB	R2,R6
	MPYS	7,R6
	SUB	R0,R6
//		proc_2(&lcl_int_1);
#ifndef	SKIP_SHORT_CIRCUITS
	LOD	lcl_int_1(SP),R0
	CMP	1,R0
	CMP.Z	13,R6
	LOD.Z	lcl_int_3(SP),R0
	CMP.Z	7,R0
	BZ	dhrystone_triple_test_still_good
	BUSY
dhrystone_triple_test_still_good:
#endif
	MOV	lcl_int_1(SP),R0
	MOV	__HERE__+2(PC),R1
	BRA	proc_2
#ifndef	SKIP_SHORT_CIRCUITS
	LOD	lcl_int_1(SP),R0
	CMP	5,R0
	BUSY.NZ
#endif

	;; Bottom of (and return from) Dhrystone main loop
	ADD	1,R11
	CMP	NUMBER_OF_RUNS,R11
	BLT	dhrystone_main_loop
//	}

#ifdef	SUPERVISOR_TASK
	LOD	(SP),R0
	LOD	1(SP),R1
	LOD	2(SP),R2
	LOD	3(SP),R3
	LOD	4(SP),R4
	LOD	5(SP),R5
	LOD	6(SP),R6
	LOD	7(SP),R7
	LOD	8(SP),R8
	LOD	9(SP),R9
	LOD	10(SP),R10
	LOD	11(SP),R11
	;
	ADD	12+RECSIZE+RECSIZE+30+30+3,SP
	; Return from subroutine
#ifndef	SKIP_SHORT_CIRCUITS
	CMP	LOAD_ADDRESS,R0
	BUSY.LT
#endif
	JMP	R0
#else
	LDI	0,CC
	NOP
	NOP
	BUSY
#endif
gbl_arr_1:
	fill	50,0
gbl_arr_2:
	fill	2500,0
gbl_ch:
	word	0
gbl_ch_2:
	word	0
gbl_bool:
	word	0
gbl_int:
	word	0
gbl_ptr:
	word	0

some_string:
	word	'D','H','R','Y','S','T','O','N','E',' '
	word	'P','R','O','G','R','A','M',',',' '
	word	'S','O','M','E',' ','S','T','R','I','N','G'
	word	0

first_string:
	word	'D','H','R','Y','S','T','O','N','E',' '
	word	'P','R','O','G','R','A','M',','
	word	' ','1','\'','S','T'
	word	' ','S','T','R','I','N','G'
	word	0

second_string:
	word	'D','H','R','Y','S','T','O','N','E',' '
	word	'P','R','O','G','R','A','M',',',' '
	word	'2','\'','N','D',' ','S','T','R','I','N','G'
	word	0

third_string:
	word	'D','H','R','Y','S','T','O','N','E',' '
	word	'P','R','O','G','R','A','M',',',' '
	word	'3','\'','R','D',' ','S','T','R','I','N','G'
	word	0

// Arr_1_Dim	gbl_arr_1;
// Arr_2_Dim	gbl_arr_2;
// char	gbl_ch, gbl_ch_2;
// bool	gbl_bool;
// int	gbl_int;
// RECP	gbl_ptr;

;
