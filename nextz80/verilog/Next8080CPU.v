//////////////////////////////////////////////////////////////////////////////////
//
// This file is part of the Next8080 project
//
// Filename: Next8080CPU.v
// Description: Implementation of 8080 compatible CPU
// Version 1.0
// Creation date: 28Jan2018
//
// Author: Nicolae Dumitrache 
// e-mail: ndumitrache@opencores.org
//
/////////////////////////////////////////////////////////////////////////////////
// 
// Copyright (C) 2018 Nicolae Dumitrache
// 
// This source file may be used and distributed without 
// restriction provided that this copyright statement is not 
// removed from the file and that any derivative work contains 
// the original copyright notice and the associated disclaimer.
// 
// This source file is free software; you can redistribute it 
// and/or modify it under the terms of the GNU Lesser General 
// Public License as published by the Free Software Foundation;
// either version 2.1 of the License, or (at your option) any 
// later version. 
// 
// This source is distributed in the hope that it will be 
// useful, but WITHOUT ANY WARRANTY; without even the implied 
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR 
// PURPOSE. See the GNU Lesser General Public License for more 
// details. 
// 
// You should have received a copy of the GNU Lesser General 
// Public License along with this source; if not, download it 
// from http://www.opencores.org/lgpl.shtml 
// 
///////////////////////////////////////////////////////////////////////////////////
//
// Comments:
//
//	Next8080 processor features:
//		Fast conditional jump/call/ret takes only 1 T state if not executed
//		Each CPU machine cycle takes (mainly) one clock T state. This makes this processor over 4 times faster than a 8080 at the same 
//			clock frequency (some instructions are up to 10 times faster). 
// Only 8080 instructions available (minus DAA, which = CPL) + some extra: JR, DJNZ
// Only IM0 supported, flags 3 and 5 always 0, opcodes ED, FD, CB treated as NOP
// No H and N flags, always 0

// Indexed mode: after the new instruction INDEX i8 [0xdd, i8], the next instruction (only) will use (mem+i8) instead of (mem)
// No interrupt is accepted after INDEX i8. i8 is a signed 8bit value.
// Indexed mode applies to the following instructions: 
//		02h = ld (bc+i8),a 
//		12h = ld (de+i8),a
//		22h = ld (hl+i8),a instead of ld (nn),hl. Ex: [0xdd 0xff 0x22] will execute ld (hl-1),a
//		32h = ld (sp+i8),a instead of ld (nn),a.  Ex: [0xdd 0x13 0x32] will execute ld (sp+13h),a
//		0Ah = ld a,(bc+i8)
//		1Ah = ld a,(de+i8)
//		2Ah = ld a,(hl+i8),a instead of ld hl,(nn)
//		3Ah = ld a,(sp+i8),a instead of ld a,(nn)
// 	All the other instructions which uses memory at (hl): ld r,(hl+i8); ld (hl+i8),r; inc (hl+i8); dec (hl+i8); ld (hl+i8),n; op a,(hl);
						
// ~450 LUT6
// See NextZ80 for more detais
///////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module Next8080
(
		input CLK,
		input RESET,
		input INT,
		input WAIT,
		input [7:0]DI,
		
		output [7:0]DO,
		output [15:0]ADDR,
		output reg WR,
		output reg MREQ,
		output reg IORQ,
		output reg HALT,
		output reg M1
);

// connections and registers
	reg	[2:0] CPUStatus = 0;	// 0=HL-DE, 1=EI, 2-indexed mode 
	wire	[7:0] ALU8FLAGS;
	wire	[7:0] FLAGS;
	wire 	[7:0] ALU80;
	wire 	[7:0] ALU81;
	wire 	[15:0]ALU160;
	wire 	[7:0] ALU161;
	wire	[15:0]ALU8OUT;

	reg 	[8:0]	FETCH = 0;
	reg 	[2:0]	STAGE = 0;
	wire	[5:0]	opd;
	wire	[2:0] op16;
	wire	op0mem = FETCH[2:0] == 6;
	wire	op1mem = FETCH[5:3] == 6;

// stage status
	reg	[1:0]DO_SEL;			// ALU80 - th - flags - ALU8OUT[7:0]
	reg	ALU160_SEL;				// regs - pc
	reg	DINW_SEL;				// ALU8OUT - DI
	reg 	[5:0]WE;			// 5 = flags, 4 = PC, 3 = SP, 2 = tmpHI, 1 = hi, 0 = lo
	reg 	[4:0] ALU8OP;
	reg 	[2:0] ALU16OP;
	reg 	next_stage;
	reg 	[3:0]REG_WSEL;
	reg 	[3:0]REG_RSEL;
	reg	[3:0]status;			// 0=HL-DE, 1=EI, 2=set EI, 3=set indexed mode
// FETCH[5:3]: 000 NZ, 001 Z, 010 NC, 011 C, 100 PO, 101 PE, 110 P, 111 M
	wire	[7:0]FlagMux = {FLAGS[7], !FLAGS[7], FLAGS[2], !FLAGS[2], FLAGS[0], !FLAGS[0], FLAGS[6], !FLAGS[6]};
	reg	tzf;
	reg 	SRESET = 0;
	reg	SINT = 0;

	N8080_Reg CPU_REGS (
		 .rstatus(CPUStatus[0]), 
		 .M1(M1), 
		 .WE(WE), 
		 .CLK(CLK), 
		 .ALU8OUT(ALU8OUT), 
		 .DI(DI), 
		 .DO(DO), 
		 .ADDR(ADDR), 									
		 .CONST({2'b00, FETCH[5:3], 3'b000}),	// RST address
		 .ALU80(ALU80), 
		 .ALU81(ALU81), 
		 .ALU160(ALU160), 
		 .ALU161(ALU161), 
		 .ALU8FLAGS(ALU8FLAGS), 
		 .FLAGS(FLAGS),
		 .DO_SEL(DO_SEL), 
		 .ALU160_sel(ALU160_SEL), 
		 .REG_WSEL(REG_WSEL), 
		 .REG_RSEL(REG_RSEL), 
		 .DINW_SEL(DINW_SEL),
		 .ALU16OP(ALU16OP),			// used for post increment for ADDR, SP mux re-direct
		 .WAIT(WAIT)
		 );

	N8080_ALU8 CPU_ALU8 (
		 .D0(ALU80), 
		 .D1(ALU81), 
		 .FIN(FLAGS), 
		 .FOUT(ALU8FLAGS), 
		 .ALU8DOUT(ALU8OUT), 
		 .OP(ALU8OP)
		 );

	N8080_ALU16 CPU_ALU16 (
		 .D0(ALU160), 
		 .D1(ALU161), 
		 .DOUT(ADDR), 
		 .OP(ALU16OP)
		 );

	always @(posedge CLK)
		if(!WAIT) begin
			SRESET <= RESET;
			SINT <= INT;
			if(SRESET) FETCH <= 9'b110000000;
			else 
				if(FETCH[8:6] == 3'b110) {FETCH[8:7]} <= 2'b00;	// exit RESET state
				else begin 
					if(M1) FETCH <= {1'b0, DI};
					if(!next_stage & SINT & CPUStatus[1] & !status[2] & !status[3]) {FETCH[8:6], FETCH[1:0]} <= {3'b100, HALT, M1};	// INT request
				end
			if(next_stage) STAGE <= STAGE + 1'b1;
			else STAGE <= 0;
			CPUStatus[0] <= CPUStatus[0] ^ status[0];
			if(status[2]) CPUStatus[1] <= status[1]; 	// EI
			if(!next_stage) CPUStatus[2] <= status[3];
			tzf <= ALU8FLAGS[6];
		end

	assign opd[0] = FETCH[0] ^ &FETCH[2:1];
	assign opd[2:1] = FETCH[2:1];
	assign opd[3] = FETCH[3] ^ &FETCH[5:4];
	assign opd[5:4] = FETCH[5:4];
	assign op16[2:0] = &FETCH[5:4] ? 3'b101 : {1'b0, FETCH[5:4]};

	always @* begin
		DO_SEL	= 2'bxx;					// ALU80 - th - flags - ALU8OUT[7:0]
		ALU160_SEL = 1'bx;					// regs - pc
		DINW_SEL = 1'bx;					// ALU8OUT - DI
		WE 		= 6'bxxxxxx;				// 5 = flags, 4 = PC, 3 = SP, 2 = tmpHI, 1 = hi, 0 = lo
		ALU8OP	= 5'bxxxxx;
		ALU16OP	= 3'b000;					// NOP, post inc
		next_stage = 0;
		REG_WSEL	= 4'bxxxx;
		REG_RSEL	= 4'bx0xx;				// prevents default 4'b0100 which leads to incorrect P flag value in some cases (like RLA)
		M1 		= 1;
		MREQ	= 1;
		WR		= 0;
		HALT = 0;
		IORQ = 0;
		status	= 4'b0000;
		

		case(FETCH[8:6])	
//------------------------------------------- block 00 ----------------------------------------------------
			3'b000:
				case(FETCH[3:0])
//				-----------------------		NOP, EX AF, AF', DJNZ, JR, JR c --------------------
					4'b0000, 4'b1000:	
						case(FETCH[5:4])
							2'b00: begin					// NOP, EX AF, AF'
								ALU160_SEL = 1;			// PC
								WE 		= 6'b010x00;	// PC
							end
							2'b01:				
								if(!STAGE[0]) begin		// DJNZ, JR - stage1
									ALU160_SEL = 1;			// pc
									WE 		= 6'b010100;	// PC, tmpHI
									ALU8OP	= 5'b01010;		// DEC, for tzf only
									REG_WSEL	= 4'b0000;	// B
									next_stage = 1;
									M1 		= 0;
								end else if(FETCH[3]) begin	// JR - stage2
									ALU160_SEL = 1;			// pc
									WE 		= 6'b010x00;	// PC
									ALU16OP	= 3;			// ADD
								end else begin				// DJNZ - stage2
									ALU160_SEL = 1;			// pc
									DINW_SEL = 0;			// ALU8OUT
									WE 		= 6'b010x10;	// PC, hi
									ALU8OP	= 5'b01010;		// DEC
									ALU16OP	= tzf ? 3'd0 : 3'd3;	// NOP/ADD
									REG_WSEL	= 4'b0000;			// B
								end
							2'b10, 2'b11: 							// JR cc, stage1, stage2
								case({STAGE[0], FlagMux[{1'b0, FETCH[4:3]}]})
									2'b00, 2'b11: begin
										ALU160_SEL = 1;				// pc
										WE 		= 6'b010x00;		// PC
										ALU16OP	= STAGE[0] ? 3'd3 : 3'd1;		// ADD/ INC, post inc
									end 
									2'b01: begin
										ALU160_SEL = 1;				// pc
										WE 		= 6'b010100;		// PC, tmpHI
										next_stage = 1; 
										M1 		= 0;
									end
								endcase
						endcase
//				-----------------------		LD rr,nn  --------------------
					4'b0001: 			// LD rr,nn, stage1
						case({STAGE[1:0], op16[2]})
							3'b00_0, 3'b00_1, 3'b01_0, 3'b01_1: begin			// LD rr,nn, stage1,2
								ALU160_SEL = 1;			// pc
								DINW_SEL = 1;				// DI
								WE 		= {4'b010x, STAGE[0] ? 1'b1 : 1'bx, !STAGE[0]};	// PC, lo/HI
								next_stage = 1;
								REG_WSEL	= {op16, 1'bx}; 
								M1 		= 0;
							end
							3'b10_0, 3'b11_1: begin		// BC, DE, HL, stage3, SP stage4
								ALU160_SEL = 1;			// pc
								WE 		= 6'b010x00;	// PC
							end
							3'b10_1: begin				// SP stage3
								ALU160_SEL = 0;			// regs
								WE 		= 6'b001x00;	// SP
								ALU16OP	= 4;				// NOP
								next_stage = 1;
								REG_RSEL	= 4'b101x;		// tmpSP
								M1 		= 0;
								MREQ		= 0;
							end
						endcase
//				-----------------------		LD (BC) A -  LD (DE) A - LD (nn) HL, LD (nn),A   --------------------
//				-----------------------		LD A (BC) -  LD A (DE) - LD HL (nn), LD A (nn)   --------------------
					4'b0010,	4'b1010:
						case(STAGE[2:0])
							3'b000:
								if(!FETCH[5] | CPUStatus[2]) begin			// LD (BC) A, LD (DE) A - stage1
									DINW_SEL = 1;	// DI
									DO_SEL	= 2'b00;		// ALU80
									ALU160_SEL = 0;				// regs
									if(CPUStatus[2]) ALU16OP = 3;					// indexed mode
									WE 		= {4'b000x, FETCH[3], 1'bx};		// hi
									next_stage = 1;
									REG_WSEL	= FETCH[3] ? 4'b011x : 4'b0110;	// A
									REG_RSEL	= {op16, 1'bx};
									M1 		= 0;
									WR = !FETCH[3];
								end else begin					// LD (nn) A - LD (nn) HL - stage 1
									ALU160_SEL = 1;				// PC
									DINW_SEL = 1;					// DI
									WE 		= 6'b010xx1;		// PC, lo
									next_stage = 1;
									REG_WSEL	= 4'b111x;
									M1 		= 0;
								end
							3'b001:
								if(!FETCH[5] | CPUStatus[2]) begin			// LD (BC), A, LD (DE), A - stage2
									ALU160_SEL = 1;				// pc
									WE 		= 6'b010x00;		// PC
								end else begin						// LD (nn),A  - LH (nn),HL - stage 2
									ALU160_SEL = 1;				// pc
									DINW_SEL = 1;					// DI
									WE 		= 6'b010x10;		// PC, hi
									next_stage = 1;
									REG_WSEL	= 4'b111x;
									M1 		= 0;
								end
							3'b010: begin					
								ALU160_SEL = 1'b0;		// regs
								REG_RSEL	= 4'b111x;
								M1 		= 0;
								WR			= !FETCH[3];
								next_stage = 1;
								if(FETCH[3]) begin		// LD A (nn)  - LD HL (nn) - stage 3
									DINW_SEL = 1;				// DI
									WE 		= {4'b000x, FETCH[4] ? 1'b1 : 1'bx, FETCH[4] ? 1'bx : 1'b1};	// lo/hi
									REG_WSEL = FETCH[4] ? 4'b011x : 4'b010x;	// A or L
								end else begin				// LD (nn),A  - LD (nn),HL - stage 3
									DO_SEL	= 2'b00;			// ALU80
									WE 		= 6'b000x00;	// nothing
									REG_WSEL = FETCH[4] ? 4'b0110 : 4'b0101;	// A or L
								end
							end
							3'b011:
								if(FETCH[4]) begin			// LD (nn),A - stage 4
									ALU160_SEL = 1;			// pc
									WE 		= 6'b010x00;	// PC
								end else begin					
									REG_RSEL	= 4'b111x;
									M1 		= 0;
									WR			= !FETCH[3];
									ALU160_SEL = 1'b0;		// regs
									ALU16OP	= 1;				// INC
									next_stage = 1;
									if(FETCH[3]) begin	// LD HL (nn) - stage 4
										DINW_SEL = 1;				// DI
										WE 		= 6'b000x10;	// hi
										REG_WSEL = 4'b010x;		// H
									end else begin			// LD (nn),HL - stage 4
										DO_SEL	= 2'b00;			// ALU80
										WE 		= 6'b000x00;	// nothing
										REG_WSEL = 4'b0100;		// H
									end
								end
							3'b100: begin				// LD (nn),HL - stage 5
								ALU160_SEL = 1;			// pc
								WE 		= 6'b010x00;	// PC
							end
						endcase
//				-----------------------		inc/dec rr   --------------------
					4'b0011, 4'b1011:
						if(!STAGE[0])
							if(op16[2]) begin			// SP - stage1
								ALU160_SEL = 0;			// regs
								WE 		= 6'b001x00;	// SP
								ALU16OP	= {FETCH[3], 1'b0, FETCH[3]};		// post inc, dec
								next_stage = 1;
								REG_RSEL	= 4'b101x;	// sp
								M1 		= 0;
								MREQ		= 0;
							end else begin				// BC, DE, HL - stage 1
								ALU160_SEL = 1;			// pc
								DINW_SEL = 0;			// ALU8OUT
								WE 		= 6'b010x11;	// PC, hi, lo
								ALU8OP	= {4'b0111, FETCH[3]};			// INC16 / DEC16
								REG_WSEL	= {op16, 1'b0};	// hi
								REG_RSEL	= {op16, 1'b1};	// lo
							end
						else 	begin				// SP, stage2
							ALU160_SEL = 1;			// pc
							WE 		= 6'b010x00;	// PC
						end
//				-----------------------		inc/dec 8  --------------------
					4'b0100, 4'b0101, 4'b1100, 4'b1101: 
						if(!op1mem) begin						//regs
							DINW_SEL = 0;						// ALU8OUT
							ALU160_SEL = 1;					// pc
							WE 		= opd[3] ? 6'b110x01 : 6'b110x10;	// flags, PC, hi/lo
							ALU8OP	= {3'b010, FETCH[0], 1'b0};		// inc / dec
							REG_WSEL	= {1'b0, opd[5:3]};
						end else case({STAGE[1:0]})
							2'b00: begin				// (HL) - stage1
								ALU160_SEL = 0;					// regs
								if(CPUStatus[2]) ALU16OP = 3;					// indexed mode
								DINW_SEL = 1;					// DI
								WE 		= 6'b000001;			// lo
								next_stage = 1;
								REG_WSEL	= 4'b011x;			// tmpLO
								REG_RSEL	= 4'b010x;			// HL
								M1 		= 0;
							end
							2'b01: begin					// (HL) stage2
								DO_SEL	= 2'b11;			// ALU80OUT
								ALU160_SEL = 0;				// regs
								if(CPUStatus[2]) ALU16OP = 3;					// indexed mode
								WE 		= 6'b100x0x;		// flags
								ALU8OP	= {3'b010, FETCH[0], 1'b0};		// inc / dec
								next_stage = 1;
								REG_WSEL	= 4'b0111;					// tmpLO
								REG_RSEL	= 4'b010x;					// HL
								M1 		= 0;
								WR			= 1;
							end
							2'b10: begin					// (HL) - stage3
								ALU160_SEL = 1;						// pc
								WE 		= 6'b010x00;				// PC
							end
						endcase
//				-----------------------		ld r/(HL), n  --------------------						
					4'b0110, 4'b1110:
						case({STAGE[1:0], op1mem})
							3'b00_0, 3'b00_1: begin		// r, (HL) - stage1 (read n)
								ALU160_SEL = 1;			// pc
								DINW_SEL = 1;			// DI
								WE 		= opd[3] ? 6'b010001 : 6'b010010;			// PC, hi/lo
								next_stage = 1;
								REG_WSEL	= {1'b0, opd[5:4], 1'bx};
								M1 		= 0;
							end
							3'b01_0, 3'b10_1: begin		// r - stage2, (HL) - stage3
								ALU160_SEL = 1;			// pc
								WE 		= 6'b010x00;	// PC
							end
							3'b01_1: begin				// (HL) - stage2
								DO_SEL	= 2'b00;		// ALU80
								ALU160_SEL = 0;			// regs
								if(CPUStatus[2]) ALU16OP = 3;					// indexed mode
								WE 		= 6'b000x0x;	// nothing
								next_stage = 1;
								REG_WSEL	= 4'b0111;	// tmpLO
								REG_RSEL	= 4'b010x;	// HL
								M1 		= 0;
								WR			= 1;
							end
						endcase
//				-----------------------		rlca, rrca, rla, rra, daa, cpl, scf, ccf  --------------------						
					4'b0111, 4'b1111: 				
						case(FETCH[5:3])
							3'b000, 3'b001, 3'b010, 3'b011, 3'b100, 3'b101: begin		// rlca, rrca, rla, rra, daa, cpl
								ALU160_SEL = 1;					// pc
								DINW_SEL = 0;					// ALU8OUT
								WE 		= 6'b110x1x;			// flags, PC, hi
								ALU8OP	= FETCH[5] ? {2'b01, !FETCH[3], 2'b01} : {3'b110, FETCH[4:3]};
								REG_WSEL	= 4'b0110;			// A
							end
							3'b110, 3'b111:	begin				// scf, ccf
								ALU160_SEL = 1;					// pc
								DINW_SEL = 0;					// ALU8OUT
								WE 		= 6'b110x0x;			// flags, PC
								ALU8OP	= {4'b1010, !FETCH[3]};
							end
						endcase
//				-----------------------		add 16  --------------------						
					4'b1001: 
						if(!STAGE[0]) begin
							DINW_SEL = 0;					// ALU8OUT
							WE 		= 6'b100x01;			// flags, lo
							ALU8OP	= 5'b10000;				// ADD16LO
							next_stage = 1;
							REG_WSEL	= 4'b0101;			// L
							REG_RSEL	= {op16, 1'b1};
							M1 		= 0;
							MREQ		= 0;
						end else begin
							ALU160_SEL = 1;					// pc
							DINW_SEL = 0;					// ALU8OUT
							WE 		= 6'b110x10;			// flags, PC, hi
							ALU8OP	= 5'b10001;				// ADD16HI
							REG_WSEL	= 4'b0100;			// H
							REG_RSEL	= {op16, 1'b0};
						end
				endcase

// ---------------------------------------------- block 01 LD8 ---------------------------------------------------
			3'b001:
				case({STAGE[0], op1mem, op0mem})
					3'b0_00,					// LD r, r 1st stage
					3'b1_01:					// LD r, (HL) 2nd stage
					begin	
						ALU160_SEL = 1;			// PC
						DINW_SEL	  = 0;		// ALU8
						WE = opd[3] ? 6'b010x01 : 6'b010x10;	// PC and LO or HI
						ALU8OP = 29;		// PASS D1
						REG_WSEL = {1'b0, opd[5:4], 1'bx};
						REG_RSEL = {1'b0, opd[2:0]};
					end
					3'b0_01:					// LD r, (HL) 1st stage
					begin	
						ALU160_SEL = 0;			// regs
						if(CPUStatus[2]) ALU16OP = 3;					// indexed mode
						DINW_SEL = 1;			// DI		
						WE 		= 6'b000x01;	// LO
						next_stage = 1;
						REG_WSEL	= 4'b011x;	// A - tmpLO
						REG_RSEL = 4'b010x;		// HL
						M1 = 0;
					end
					3'b0_10: 					// LD (HL), r 1st stage
					begin	
						DO_SEL	= 0;			// ALU80
						ALU160_SEL = 0;			// regs
						if(CPUStatus[2]) ALU16OP = 3;					// indexed mode
						WE 		= 6'b000x00;	// no write
						next_stage = 1;
						REG_WSEL	= {1'b0, opd[2:0]};
						REG_RSEL	= 4'b010x;	// HL
						M1 		= 0;
						WR			= 1;			
					end
					3'b1_10: 					// LD (HL), r 2nd stage
					begin	
						ALU160_SEL = 1;			// pc
						WE 		= 6'b010x00;	// PC
					end
					3'b0_11: begin				// HALT
						WE 		= 6'b000x00;	// no write
						M1 		= 0;
						MREQ		= 0;
						HALT 		= 1;
					end
				endcase
// ---------------------------------------------- block 10 arith8 ---------------------------------------------------
			3'b010:
				case({STAGE[0], op0mem})
					2'b0_0,					// OP r,r 1st stage
					2'b1_1:					// OP r, (HL) 2nd stage
					begin
						ALU160_SEL = 1;			// pc
						DINW_SEL = 0;			// ALU8OUT
						WE 		= {4'b110x, ~&FETCH[5:3], 1'bx};	// flags, PC, hi
						ALU8OP	= {2'b00, FETCH[5:3]};
						REG_WSEL	= 4'b0110;	// A
						REG_RSEL	= {1'b0, opd[2:0]};
					end
					2'b0_1:					// OP r, (HL) 1st stage
					begin
						ALU160_SEL = 0;			// regs
						if(CPUStatus[2]) ALU16OP = 3;					// indexed mode
						DINW_SEL = 1;			// DI
						WE 		= 6'b000x01;	// lo
						next_stage = 1;
						REG_WSEL	= 4'b011x;	// A-tmpLO
						REG_RSEL	= 4'b010x;	// HL
						M1 		= 0;
					end
				endcase
//------------------------------------------- block 11 ----------------------------------------------------
			3'b011:
				case(FETCH[3:0])
//				-----------------------		RET cc --------------------
					4'b0000, 4'b1000:
						case(STAGE[1:0])
							2'b00, 2'b01:			// stage1, stage2
								if(FlagMux[FETCH[5:3]]) begin	// POP addr
									ALU160_SEL = 0;				// regs
									DINW_SEL = 1;					// DI
									WE 		= {4'b001x, STAGE[0] ? 1'b1 : 1'bx, !STAGE[0]};		// SP, lo/hi
									next_stage = 1;
									REG_WSEL	= 4'b111x;			// tmp16
									REG_RSEL	= 4'b101x;			// SP
									M1 		= 0;
								end else begin
									ALU160_SEL = 1;				// pc
									WE 		= 6'b010x00;		// PC
								end
							2'b10: begin			// stage3
								ALU160_SEL = 0;					// regs
								WE 		= 6'b010x00;			// PC
								REG_RSEL	= 4'b111x;				// tmp16
							end
						endcase
//				-----------------------		POP --------------------
					4'b0001:
						case(STAGE[1:0])
							2'b00, 2'b01: begin
								if(op16[2]) begin	// AF
									WE 		= STAGE[0] ? 6'b101x1x : 6'b001xx1;		// flags, SP, lo/hi
									REG_WSEL	= {3'b011, STAGE[0] ? 1'b1 : 1'bx};
									if(STAGE[0]) ALU8OP	= 30;						// FLAGS <- D0
								end else begin		// r16
									WE 		= STAGE[0] ? 6'b001x10 : 6'b001xx1;		// SP, lo/hi
									REG_WSEL	= {1'b0, FETCH[5:4], 1'bx};
								end
								ALU160_SEL = 0;			// regs
								DINW_SEL = 1;				// DI
								next_stage = 1;
								REG_RSEL	= 4'b101x;		// SP
								M1 		= 0;
							end
							2'b10: begin					// stage3
								ALU160_SEL = 1;			// PC
								WE 		= 6'b010x00;	// PC
							end
						endcase
//				-----------------------		JP cc --------------------
					4'b0010, 4'b1010:
						case(STAGE[1:0])
							2'b00, 2'b01:	begin				// stage1,2
								if(FlagMux[FETCH[5:3]]) begin
									ALU160_SEL = 1;					// pc
									DINW_SEL = 1;						// DI
									WE 		= {4'b010x, STAGE[0] ? 1'b1 : 1'bx, !STAGE[0]};		// PC, hi/lo
									next_stage = 1;
									REG_WSEL	= 4'b111x;				// tmp7
									M1 		= 0;
								end else begin
									ALU160_SEL = 1;					// pc
									WE 		= 6'b010x00;			// PC
									ALU16OP	= 2;						// add2
								end
							end
							2'b10: begin						// stage3
								ALU160_SEL = 0;					// regs
								WE 		= 6'b010x00;			// PC
								REG_RSEL	= 4'b111x;				// tmp7
							end
						endcase
//				-----------------------		JP, OUT (n) A, EX (SP) HL, DI --------------------
					4'b0011:
						case(FETCH[5:4])
							2'b00:					// JP
								case(STAGE[1:0])
									2'b00, 2'b01:	begin				// stage1,2 - read addr
										ALU160_SEL = 1;					// pc
										DINW_SEL = 1;						// DI
										WE 		= {4'b010x, STAGE[0] ? 1'b1 : 1'bx, !STAGE[0]};		// PC, hi/lo
										next_stage = 1;
										REG_WSEL	= 4'b111x;				// tmp7
										M1 		= 0;
									end
									2'b10: begin						// stage3
										ALU160_SEL = 0;					// regs
										WE 		= 6'b010x00;			// PC
										REG_RSEL	= 4'b111x;				// tmp7
									end
								endcase
							2'b01: 					// OUT (n), a - stage1 - read n
								case(STAGE[1:0])
									2'b00: begin
										ALU160_SEL = 1;					// pc
										DINW_SEL = 1;						// DI
										WE 		= 6'b010x01;			// PC, lo
										next_stage = 1;
										REG_WSEL	= 4'b011x;				// tmpLO
										M1 		= 0;
									end
									2'b01: begin		// stage2 - OUT
										DO_SEL	= 2'b00;					// ALU80
										ALU160_SEL = 0;					// regs
										WE 		= 6'b000x00;			// nothing
										next_stage = 1;
										REG_WSEL	= 4'b0110;				// A
										REG_RSEL	= 4'b011x;				// A-tmpLO
										M1 		= 0;
										MREQ		= 0;
										WR 		= 1;
										IORQ		= 1;
									end
									2'b10: begin		// stage3 - fetch
										ALU160_SEL = 1;			// PC
										WE 		= 6'b010x00;	// PC
									end
								endcase
							2'b10:				// EX (SP), HL
								case(STAGE[2:0])
									3'b000, 3'b001:	begin			// stage1,2 - pop tmp16
										ALU160_SEL = 0;					// regs
										DINW_SEL = 1;						// DI
										WE 		= {4'b001x, STAGE[0] ? 1'b1 : 1'bx, !STAGE[0]};			// SP, lo/hi
										next_stage = 1;
										REG_WSEL	= 4'b111x;				// tmp16
										REG_RSEL	= 4'b101x;				// SP
										M1 		= 0;
									end
									3'b010, 3'b011: begin			// stage3,4 - push hl
										DO_SEL	= 2'b00;					// ALU80
										ALU160_SEL = 0;					// regs
										WE 		= 6'b001x00;			// SP
										ALU16OP	= 5;						// dec
										next_stage = 1;
										REG_WSEL	= {3'b010, STAGE[0]};// H/L	
										REG_RSEL	= 4'b101x;				// SP
										M1 		= 0;
										WR			= 1;
									end
									3'b100, 3'b101: begin		// stage5,6
										ALU160_SEL = 1;					// pc
										DINW_SEL = 0;						// ALU8OUT
										WE 		= {1'b0, STAGE[0], 2'b0x, STAGE[0] ? 1'b1 : 1'bx, !STAGE[0]};	// PC, lo/hi
										ALU8OP	= 29;		// pass D1
										next_stage = !STAGE[0];
										REG_WSEL	= 4'b010x;		// HL
										REG_RSEL	= {3'b111, !STAGE[0]};		// tmp16
										M1 		= STAGE[0];
										MREQ		= STAGE[0];
									end
								endcase
							2'b11:	begin			// DI
								ALU160_SEL = 1;			// PC
								WE 		= 6'b010x00;	// PC
								status[2:1] = 2'b10;	// set EI flags
							end
						endcase
//				-----------------------		CALL cc --------------------
					4'b0100, 4'b1100:	
						case(STAGE[2:0])
							3'b000, 3'b001:		// stage 1,2 - load addr
								if(FlagMux[FETCH[5:3]]) begin
									ALU160_SEL = 1;					// pc
									DINW_SEL = 1;						// DI
									WE 		= {4'b010x, STAGE[0] ? 1'b1 : 1'bx, !STAGE[0]};		// PC, hi/lo
									next_stage = 1;
									REG_WSEL	= 4'b111x;				// tmp7
									M1 		= 0;
								end else begin
									ALU160_SEL = 1;					// pc
									WE 		= 6'b010x00;			// PC
									ALU16OP	= 2;						// add2
								end
							3'b010, 3'b011: begin		// stage 3,4 - push pc
								DO_SEL	= {1'b0, STAGE[0]};	// pc hi/lo
								ALU160_SEL = 0;					// regs
								WE 		= 6'b001x00;			// SP
								ALU16OP	= 5;						// DEC
								next_stage = 1;
								REG_WSEL	= 4'b1xxx;				// pc
								REG_RSEL	= 4'b101x;				// sp
								M1 		= 0;
								WR			= 1;
							end
							3'b100:	begin	// stage5
								ALU160_SEL = 0;					// regs
								WE 		= 6'b010x00;			// PC
								REG_RSEL	= 4'b111x;				// tmp7
							end
						endcase
//				-----------------------		PUSH --------------------
					4'b0101: 
						case(STAGE[1:0])
							2'b00, 2'b01: begin			// stage1,2
								DO_SEL	= {STAGE[0] & op16[2], 1'b0};		// FLAGS/ALU80
								ALU160_SEL = 0;				// regs
								WE 		= 6'b001x00;		// SP
								ALU16OP	= 5;  				// dec
								next_stage = 1;
								REG_WSEL	= {1'b0, FETCH[5:4], STAGE[0]};
								REG_RSEL	= 4'b101x;				// SP
								M1 		= 0;
								WR			= 1;
							end
							2'b10: begin					//stage3
								ALU160_SEL = 1;				// PC
								WE 		= 6'b010x00;		// PC
							end
						endcase
//				-----------------------		op A, n  --------------------
					4'b0110, 4'b1110:
						if(!STAGE[0]) begin			// stage1, read n
							ALU160_SEL = 1;					// pc
							DINW_SEL = 1;						// DI
							WE 		= 6'b010x01;			// PC, lo
							next_stage = 1;
							REG_WSEL	= 4'b011x;				// tmpLO
							M1 		= 0;
						end else begin					// stage 2
							DINW_SEL = 0;						// ALU8OUT[7:0]
							ALU160_SEL = 1;					// pc
							WE 		= {4'b110x, ~&FETCH[5:3], 1'bx};			// flags, PC, hi
							ALU8OP	= {2'b00, FETCH[5:3]};
							REG_WSEL	= 4'b0110;				// A
							REG_RSEL	= 4'b0111;				// tmpLO
						end
//				-----------------------		RST  --------------------
					4'b0111, 4'b1111:
						case(STAGE[1:0])
							2'b00, 2'b01: begin		// stage 1,2 - push pc
								DO_SEL	= {1'b0, STAGE[0]};	// pc hi/lo
								ALU160_SEL = 0;					// regs
								WE 		= 6'b001x00;			// SP
								ALU16OP	= 5;						// DEC
								next_stage = 1;
								REG_WSEL	= 4'b1xxx;				// pc
								REG_RSEL	= 4'b101x;				// sp
								M1 		= 0;
								WR			= 1;
							end
							2'b10:	begin				// stage3
								ALU160_SEL = 0;					// regs
								WE 		= 6'b010x00;			// PC
								REG_RSEL	= 4'b110x;				// const
							end
						endcase
//				-----------------------		RET, EXX, JP (HL), LD SP HL --------------------
					4'b1001:	
						case(FETCH[5:4])	
							2'b00: 				// RET
								case(STAGE[1:0])
									2'b00, 2'b01:	begin		// stage1, stage2 - pop addr
										ALU160_SEL = 0;				// regs
										DINW_SEL = 1;					// DI
										WE 		= {4'b001x, STAGE[0] ? 1'b1 : 1'bx, !STAGE[0]};		// SP, lo/hi
										next_stage = 1;
										REG_WSEL	= 4'b111x;			// tmp16
										REG_RSEL	= 4'b101x;			// SP
										M1 		= 0;
									end		
									2'b10: begin			// stage3 - jump
										ALU160_SEL = 0;					// regs
										WE 		= 6'b010x00;			// PC
										REG_RSEL	= 4'b111x;				// tmp16
									end
								endcase
							2'b01: begin			// EXX
								ALU160_SEL = 1;			// PC
								WE 		= 6'b010x00;	// PC
							end
							2'b10:	begin		// JP (HL)
								ALU160_SEL = 0;					// regs
								WE 		= 6'b010x00;			// PC
								REG_RSEL	= 4'b010x;				// HL
							end
							2'b11: begin	// LD SP,HL	
								if(!STAGE[0]) begin			// stage1
									ALU160_SEL = 0;				// regs
									WE 		= 6'b001x00;		// SP
									ALU16OP	= 4;					// NOP, no post inc
									next_stage = 1;
									REG_RSEL	= 4'b010x;			// HL
									M1 		= 0;
									MREQ		= 0;
								end else begin						// stage2
									ALU160_SEL = 1;				// pc
									WE 		= 6'b010x00;		// PC
								end
							end
						endcase
//				-----------------------		CB, IN A (n), EX DE HL, EI --------------------
					4'b1011:
						case(FETCH[5:4])
							2'b00: begin 				// CB prefix, nop
								ALU160_SEL = 1;			// PC
								WE 		= 6'b010000;	// PC
							end
							2'b01:					// IN A, (n)
								case(STAGE[1:0])
									2'b00: begin		//stage1 - read n
										ALU160_SEL = 1;				// pc
										DINW_SEL = 1;					// DI
										WE 		= 6'b010x01;		// PC, lo
										next_stage = 1;
										REG_WSEL	= 4'b011x;			// tmpLO
										M1 		= 0;
									end
									2'b01: begin		// stage2 - IN
										ALU160_SEL = 0;				// regs
										DINW_SEL = 1;					// DI
										WE 		= 6'b000x1x;		// hi
										next_stage = 1;
										REG_WSEL	= 4'b011x;			// A
										REG_RSEL	= 4'b011x;			// A - tmpLO
										M1 		= 0;
										MREQ		= 0;
										IORQ		= 1;
									end
									2'b10: begin		// stage3 - fetch
										ALU160_SEL = 1;			// PC
										WE 		= 6'b010x00;	// PC
									end
								endcase
							2'b10: begin			// EX DE, HL
								ALU160_SEL = 1;			// PC
								WE 		= 6'b010x00;	// PC
								status[0] = 1;
							end
							2'b11: begin			// EI
								ALU160_SEL = 1;			// PC
								WE 		= 6'b010x00;	// PC
								status[2:1] = 2'b11;
							end
						endcase
//				-----------------------		CALL , DD, ED, FD --------------------
					4'b1101:	
						case(FETCH[5:4])
							2'b00: 					// CALL
								case(STAGE[2:0])
									3'b000, 3'b001: begin				// stage 1,2 - load addr
										ALU160_SEL = 1;					// pc
										DINW_SEL = 1;					// DI
										WE 		= {4'b010x, STAGE[0] ? 1'b1 : 1'bx, !STAGE[0]};		// PC, hi/lo
										next_stage = 1;
										REG_WSEL	= 4'b111x;			// tmp7
										M1 		= 0;
									end
									3'b010, 3'b011: begin		// stage 3,4 - push pc
										DO_SEL	= {1'b0, STAGE[0]};	// pc hi/lo
										ALU160_SEL = 0;					// regs
										WE 		= 6'b001x00;			// SP
										ALU16OP	= 5;					// DEC
										next_stage = 1;
										REG_WSEL	= 4'b1xxx;			// pc
										REG_RSEL	= 4'b101x;			// sp
										M1 		= 0;
										WR			= 1;
									end
									3'b100:	begin	// stage5 - jump
										ALU160_SEL = 0;					// regs
										WE 		= 6'b010x00;			// PC
										REG_RSEL	= 4'b111x;			// tmp7
									end
								endcase
							2'b01: begin	// DD - indexed mode
								ALU160_SEL = 1;				// PC
								if(!STAGE[0]) begin
									WE 		= 6'b010100;	// PC, tmpHI
									next_stage = 1;
									M1 		= 0;
								end else begin
									WE = 6'b010000;		// PC
									status[3] = 1'b1; 	// set indexed mode
								end
							end
							2'b10, 2'b11: begin		// ED, FD - IY
								ALU160_SEL = 1;				// PC
								WE 		= 6'b010x00;		// PC
							end
						endcase
				endcase

//------------------------------------------- // RST, INT ----------------------------------------------------
			3'b110: begin 			// RESET: DI, pC <- 0
				ALU160_SEL = 0;					// regs
				WE 		= 6'bx1xx00;			// PC
				ALU16OP	= 4;					// NOP
				REG_RSEL	= 4'b110x;			// const
				M1 		= 0;
				MREQ		= 0;
				status[2:1] = 2'b10;			// DI
			end 
			3'b100: begin				// INT
				ALU160_SEL = 1;					// pc
				WE 		= 6'b010x00;			// PC
				ALU16OP	= FETCH[1] ? 4 : 5;		// NOP(HALT)/DEC(else)
				MREQ		= 0;
				IORQ		= 1;
				status[2:1]	= 2'b10;			// DI
			end
		endcase	
	end

endmodule

//FLAGS: S Z X1 N X2 PV N C
//	OP[4:0]
//	00000	-	ADD	D0,D1
//	00001	-	ADC	D0,D1
//	00010	-	SUB	D0,D1
//	00011	-	SBC	D0,D1
//	00100	-	AND	D0,D1
//	00101	-	XOR	D0,D1
//	00110	-	OR		D0,D1
//	00111	-	CP		D0,D1
//	01000	-	INC	D0
//	01001	-	CPL	D0
// 01010	-	DEC	D0
//	01101	-	DAA=CPL
//	01110	-	INC16
//	01111	-  DEC16
// 10000	-	ADD16LO
//	10001	-	ADD16HI
//	10010	-	
//	10011	-	
//	10100	-	CCF, pass D0
// 10101	-	SCF, pass D0
// 10110	-	
//	10111	-	
//	11000	-	RLCA	D0
//	11001	-	RRCA	D0
//	11010	-	RLA	D0
//	11011	- 	RRA	D0
//	11101	-	IN, pass D1
//	11110	-	FLAGS <- D0
///////////////////////////////////////////////////////////////////////////////////
module N8080_ALU8(
    input [7:0]D0,
    input [7:0]D1,
	 input [7:0]FIN,
    input [4:0]OP,
	 
    output reg[7:0]FOUT,
    output reg [15:0]ALU8DOUT
    );
	
	wire parity = ~^ALU8DOUT[15:8];
	wire zero = ~|ALU8DOUT[15:8];
	reg cin;
	reg [7:0]_d1mux;
	wire [7:0]d1mux = OP[1] ? ~_d1mux : _d1mux;
	wire [8:0]sum = D0 + d1mux + cin;
	wire overflow = (D0[7] & d1mux[7] & !sum[7]) | (!D0[7] & !d1mux[7] & sum[7]);
	wire [7:0]log;
	reg [3:0]logop;
	wire csin = OP[1] ? FIN[0] : OP[0] ? D0[0] : D0[7];
	wire [7:0]shift = OP[0] ? {csin, D0[7:1]} : {D0[6:0], csin};
	wire [15:0]inc16 = OP[0] ? {D0, D1} - 1'b1 : {D0, D1} + 1'b1;
	
	N8080_LOG8 log8_unit
	(
		.A(D0), 
		.B(D1), 
		.O(log),
		.op(logop)
	);

	always @* begin
		ALU8DOUT = {sum[7:0], sum[7:0]};
		logop = 4'bxxxx;
		case({OP[4:2]})
			0,1,4,7: _d1mux = D1;
			default: _d1mux = 8'h01;
		endcase
		case({OP[2:0], FIN[0]})
			0,1,2,7,8,9,10,11,12,13: cin = 0;
			3,4,5,6,14,15: cin = 1;
		endcase
		
		FOUT = {FIN[7:6], 3'b000, FIN[2], 1'b0, FIN[0]};
		case(OP[4:0])
			0,1,2,3,8,10:	begin		// ADD, ADC, SUB, SBC, INC, DEC
				FOUT[0] = OP[3] ? FIN[0] : (sum[8] ^ OP[1]); // inc/dec
				FOUT[2] = overflow;
				FOUT[6] = zero;
				FOUT[7] = ALU8DOUT[15];
			end
			16,17:	begin		// ADD16LO, ADD16HI
				FOUT[0] = sum[8];
			end
			7: begin		// CP
				FOUT[0] = !sum[8];
				FOUT[2] = overflow;
				FOUT[6] = zero;
				FOUT[7] = ALU8DOUT[15];
			end
			4,5,6: begin		//AND, XOR, OR
				ALU8DOUT = {log, log};
				logop = OP[0] ? 4'b0110 : OP[1] ? 4'b1110 : 4'b1000;
				FOUT[0] = 0;
				FOUT[2] = parity;
				FOUT[6] = zero;
				FOUT[7] = ALU8DOUT[15];
			end
			9,13: begin			// CPL
				ALU8DOUT = {log, log};
				logop = 4'b0011; // ~D0
				FOUT[0] = FIN[0];
			end
			14,15: begin	// inc/dec 16
				ALU8DOUT = inc16;
				FOUT[2] = ALU8DOUT != 0;
			end
			20,21: begin		// CCF, SCF
				ALU8DOUT = {log, log};
				logop = 4'b1100; // D0
				FOUT[0] = OP[0] ? 1'b1 : !FIN[0];
			end
			24,25,26,27: begin 							// ROT
				ALU8DOUT[15:8] = {shift, shift};
				FOUT[0] = OP[0] ? D0[0] : D0[7];
			end
			29:	begin		// IN, pass D1
				ALU8DOUT = {log, log};
				logop = 4'b1010; // D1
				FOUT[2] = parity;
				FOUT[6] = zero;
				FOUT[7] = ALU8DOUT[15];
			end
			30: {FOUT[7:6], FOUT[2], FOUT[0]} = {D0[7:6], D0[2], D0[0]};		// FLAGS <- D0
			default:;
		endcase
	end
endmodule

module N8080_LOG8(
	input [7:0]A,
	input [7:0]B,
	input [3:0]op, // 0=0, 1=~(A|B), 2=~A&B, 3=~A, 4=A&~B, 5=~B, 6=A^B, 7=~(A&B), 8=A&B, 9=~(A^B), 10=B, 11=~A|B, 12=A, 13=A|~B, 14=A|B, 15=-1
	
	output [7:0]O
	);
	
	assign O[0] = op[{A[0], B[0]}];
	assign O[1] = op[{A[1], B[1]}];
	assign O[2] = op[{A[2], B[2]}];
	assign O[3] = op[{A[3], B[3]}];
	assign O[4] = op[{A[4], B[4]}];
	assign O[5] = op[{A[5], B[5]}];
	assign O[6] = op[{A[6], B[6]}];
	assign O[7] = op[{A[7], B[7]}];
endmodule

module N8080_ALU16(
    input [15:0]D0,
    input [7:0]D1,
    input [2:0]OP,	// 0-NOP, 1-INC, 2-INC2, 3-ADD, 4-NOP, 5-DEC, 6-DEC2
	 
    output wire[15:0] DOUT
    );
	
	reg [7:0] mux;
	always @*
		case(OP)
			0: mux = 8'd0;			// post inc
			1: mux = 8'd1;			// post inc
			2: mux = 8'd2;			// post inc
			3: mux = D1;			// post inc
			4: mux = 8'd0;			// no post inc			
			5: mux = -8'd1;		// no post inc
			6: mux = -8'd2;		// no post inc
			7: mux = 8'dx;
		endcase
	
	assign DOUT = D0 + {{8{mux[7]}}, mux};
endmodule

module N8080_Reg(
	input rstatus,			// hl-de
	input M1,
	input [5:0]WE,			// 5 = flags, 4 = PC, 3 = SP, 2 = tmpHI, 1 = hi, 0 = lo
	input CLK,
	input [15:0]ALU8OUT,	// CPU data out bus (output of alu8)
	input [7:0]DI,			// CPU data in bus
	input [15:0]ADDR,		// CPU addr bus
	input [7:0]CONST,
	input [7:0]ALU8FLAGS,			
	input [1:0]DO_SEL,		// select DO betwen ALU8OUT lo and th register
	input ALU160_sel,		// 0=REG_RSEL, 1=PC
	input [3:0]REG_WSEL,	// rdow:    	[3:1] 0=BC, 1=DE, 2=HL, 3=A-TL, 4=I-x  ----- [0] = 0HI,1LO
	input [3:0]REG_RSEL,	// mux_rdor:   [3:1] 0=BC, 1=DE, 2=HL, 3=A-TL, 4=I-R, 5=SP, 7=tmp   ----- [0] = 0HI, 1LO
	input DINW_SEL,		// select RAM write data between (0)ALU8OUT, and 1(DI)
	input [2:0]ALU16OP,	// ALU16OP
	input WAIT,				// wait

	output reg [7:0]DO,			// CPU data out bus
	output reg [7:0]ALU80,
	output reg [7:0]ALU81,
	output reg [15:0]ALU160,
	output [7:0]ALU161,
	output [7:0]FLAGS
	);
	
// latch registers
	reg [15:0]pc=0;				// program counter
	reg [15:0]sp;				// stack pointer
	reg [7:0]flg = 0;
	reg [7:0]th;				// temp high

// internal wires	
	wire [15:0]rdor;	// R out from RAM
	wire [15:0]rdow;	// W out from RAM
	wire [2:0]SELW;		// RAM W port sel
	wire [2:0]SELR;		// RAM R port sel
	reg  [15:0]DIN;		// RAM W in data
	reg [15:0]mux_rdor;	// (3)A reversed mixed with TL, (4)I mixed with R (5)SP
	
//------------------------------------ RAM block registers ----------------------------------
// 0:BC, 1:DE, 2:HL, 3:A-x, 4:BC', 5:DE', 6:HL', 7:A'-x, 8:tmp
   N8080_RAM16X8D_regs regs_lo (
      .DPO(rdor[7:0]),   // Read-only data output
      .SPO(rdow[7:0]),   // R/W data output
      .A(SELW),       	 // R/W address
      .D(DIN[7:0]),      // Write data input
      .DPRA(SELR), 		 // Read-only address
      .WCLK(CLK),   	 // Write clock input
      .WE(WE[0] & !WAIT) // Write enable input
   );

   N8080_RAM16X8D_regs regs_hi (
      .DPO(rdor[15:8]),  // Read-only data output
      .SPO(rdow[15:8]),  // R/W data output
      .A(SELW),       	 // R/W address
      .D(DIN[15:8]),     // Write data input
      .DPRA(SELR), 		 // Read-only address
      .WCLK(CLK),   	 // Write clock input
      .WE(WE[1] & !WAIT) // Write enable input
   );

	wire [15:0]ADDR1 = ADDR + !ALU16OP[2]; // address post increment
	always @(posedge CLK)
		if(!WAIT) begin
			if(WE[2]) th <= DI;
			if(WE[3]) sp <= ADDR1;
			if(WE[4]) pc <= ADDR1;
			if(WE[5]) flg <= ALU8FLAGS;
		end
	
	assign ALU161 = th;
	assign FLAGS = flg;
	
	always @* begin
		DIN = DINW_SEL ? {DI, DI} : ALU8OUT;
		ALU80 = REG_WSEL[0] ? rdow[7:0] : rdow[15:8];
		ALU81 = REG_RSEL[0] ? mux_rdor[7:0] : mux_rdor[15:8];
		ALU160 = ALU160_sel ? pc : mux_rdor;
	
		case({REG_WSEL[3], DO_SEL})
			0:	DO = ALU80;
			1:	DO = th;
			2: 	DO = FLAGS;
			3: 	DO = ALU8OUT[7:0];
			4: 	DO = pc[15:8];
			5: 	DO = pc[7:0];
			6:	DO = sp[15:8];
			7: 	DO = sp[7:0];
		endcase
		case({ALU16OP == 4, REG_RSEL[3:0]})
			5'b01010, 5'b01011: mux_rdor = sp;
			5'b01100, 5'b01101, 5'b11100, 5'b11101:	mux_rdor = {8'b0, CONST};
			default: mux_rdor = rdor;
		endcase 
	end
	
	N8080_RegSelect WSelectW(.SEL(REG_WSEL[3:1]), .RAMSEL(SELW), .rstatus(rstatus));
	N8080_RegSelect WSelectR(.SEL(REG_RSEL[3:1]), .RAMSEL(SELR), .rstatus(rstatus));

endmodule


module N8080_RegSelect(
	input [2:0]SEL,
	input rstatus,			// 2=hl-de
	
	output reg [2:0]RAMSEL
	);
	
	always @* begin
		case(SEL)
			0: RAMSEL = 3'b000;	// BC
			1: RAMSEL = rstatus ? 3'b010 : 3'b001;	// HL - DE
			2: RAMSEL = rstatus ? 3'b001 : 3'b010;	// DE - HL
			3: RAMSEL = 3'b011; 					// A-TL
			default: RAMSEL = 3'b100;	// I-R, tmp SP, zero, temp
		endcase
	end
endmodule	

module N8080_RAM16X8D_regs(
      input [2:0]A,       	// R/W address 
      input [7:0]D,        // Write data input
      input [2:0]DPRA, 		// Read-only address
      input WCLK,   			// Write clock
      input WE,        		// Write enable

      output [7:0]DPO,     // Read-only data output
      output [7:0]SPO     // R/W data output
   );
	
	reg [7:0]data[4:0];
	assign DPO = data[DPRA];
	assign SPO = data[A];
	
	always @(posedge WCLK)
		if(WE) data[A] <= D;		

endmodule

