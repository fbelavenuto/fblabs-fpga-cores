///////////////////////////////////////////////////////////////////////////////
//
// Filename:	idecode_deprecated.v
//
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:	This RTL file specifies how the original instruction set was
//		to be decoded into a machine understandable microcode.  It has
//	been drawn out of zipcpu.v in an effort to provide some encapsulation,
//	some of measuring its performance independently, and some means of
//	updating it without impacting everything else (much).
//
//	It has since been deprecated by a newer version of the instruction
//	set architecture.
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
///////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015, Gisselquist Technology, LLC
//
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of  the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
///////////////////////////////////////////////////////////////////////////////
//
//
//
//
`define	CPU_CC_REG	4'he
`define	CPU_PC_REG	4'hf
//
//
//
module	idecode_deprecated(i_clk, i_rst, i_ce, i_stalled,
		i_instruction, i_gie, i_pc, i_pf_valid, i_illegal,
		o_phase, o_illegal,
		o_pc, o_gie, o_R, o_A, o_B,
		o_I, o_zI, o_cond, o_wF, o_op,
		o_ALU, o_M, o_DV, o_FP, o_break, o_lock,
		o_wR, o_rA, o_rB,
		o_early_branch, o_branch_pc, o_pipe
		);
	parameter	ADDRESS_WIDTH=24, IMPLEMENT_MPY=1, EARLY_BRANCHING=1,
			IMPLEMENT_DIVIDE=0, IMPLEMENT_FPU=0, AW=ADDRESS_WIDTH;
	input		i_clk, i_rst, i_ce, i_stalled;
	input	[31:0]	i_instruction;
	input		i_gie;
	input	[(AW-1):0]	i_pc;
	input			i_pf_valid, i_illegal;
	output	wire		o_phase;
	output	reg		o_illegal;
	output	reg	[(AW-1):0]	o_pc;
	output	reg		o_gie;
	output	wire	[6:0]	o_R;
	output	reg	[6:0]	o_A, o_B;
	output	wire	[31:0]	o_I;
	output	reg		o_zI;
	output	reg	[3:0]	o_cond;
	output	reg		o_wF;
	output	reg	[3:0]	o_op;
	output	wire		o_ALU, o_DV, o_FP;
	output	reg		o_M, o_break, o_lock;
	output	reg		o_wR, o_rA, o_rB;
	output	wire		o_early_branch;
	output	wire	[(AW-1):0]	o_branch_pc;
	output	wire		o_pipe;


	assign	o_phase = 1'b0;
	assign	o_R  = { (o_A[6]), (o_A[5]), o_A[4:0] };

	//
	//
	//	PIPELINE STAGE #2 :: Instruction Decode
	//		Variable declarations
	//
	//
	reg	[23:0]	r_I;
	reg		r_zI;	// true if dcdI == 0

	generate
	if (EARLY_BRANCHING != 0)
	begin
		reg			r_early_branch;
		reg	[(AW-1):0]	r_branch_pc;
		assign	o_early_branch     = r_early_branch;
		assign	o_branch_pc = r_branch_pc;

		always @(posedge i_clk)
			if ((i_ce)&&(i_pf_valid)&&(i_instruction[27:24]==`CPU_PC_REG))
			begin
				r_early_branch <= 1'b0;
				// First case, a move to PC instruction
				if ((i_instruction[31:28] == 4'h2)
					// Offsets of the PC register *only*
					&&(i_instruction[19:16] == `CPU_PC_REG)
					&&((i_gie)
						||((~i_instruction[20])&&(~i_instruction[15])))
					&&(i_instruction[23:21]==3'h0)) // Unconditional
				begin
					r_early_branch <= 1'b1;
					
				end else // Next case, an Add Imm -> PC instruction
				if ((i_instruction[31:28] == 4'ha) // Add
					&&(~i_instruction[20]) // Immediate
					&&(i_instruction[23:21]==3'h0)) // Always
				begin
					r_early_branch <= 1'b1;
				end else // Next case: load Immediate to PC
				if (i_instruction[31:28] == 4'h3)
				begin
					r_early_branch <= 1'b1;
				end
			end else
			begin
				if (i_ce) r_early_branch <= 1'b0;
			end

		if (AW == 24)
		begin
			always @(posedge i_clk)
			if (i_ce)
			begin
				if (i_instruction[31]) // Add
				begin
					r_branch_pc <= i_pc
							+ { {(AW-20){i_instruction[19]}}, i_instruction[19:0] }
							+ {{(AW-1){1'b0}},1'b1};
				end else if (~i_instruction[28]) // 4'h2 = MOV
					r_branch_pc <= i_pc+{ {(AW-15){i_instruction[14]}}, i_instruction[14:0] } + {{(AW-1){1'b0}},1'b1};
				else // if (i_instruction[28]) // 4'h3 = LDI
					r_branch_pc <= i_pc+{ i_instruction[23:0] } + {{(AW-1){1'b0}},1'b1};
			end
		end else begin
			always @(posedge i_clk)
			if (i_ce)
			begin
				if (i_instruction[31]) // Add
				begin
					r_branch_pc <= i_pc
								+ { {(AW-20){i_instruction[19]}}, i_instruction[19:0] }
								+ {{(AW-1){1'b0}},1'b1};
				end else if (~i_instruction[28]) // 4'h2 = MOV
				begin
						r_branch_pc <= i_pc+{ {(AW-15){i_instruction[14]}}, i_instruction[14:0] } + {{(AW-1){1'b0}},1'b1};
				end else // if (i_instruction[28]) // 4'h3 = LDI
				begin
					r_branch_pc <= i_pc+{ {(AW-24){i_instruction[23]}}, i_instruction[23:0] } + {{(AW-1){1'b0}},1'b1};
				end
			end
	end end else begin // No early branching
		// wire			o_early_branch;
		// wire	[(AW-1):0]	o_branch_pc;
		assign	o_early_branch     = 1'b0;
		assign	o_branch_pc = {(AW){1'b0}};
	end endgenerate

	wire	[4:0]	w_A, w_B;
	wire		w_mpy, w_wF, w_ldixx, w_zI;
	wire	[3:0]	w_op;
	wire	[23:0]	w_I;

	assign	w_op= i_instruction[31:28];
	assign	w_I = (w_op == 4'h2) ?
				{ {(9){i_instruction[14]}},i_instruction[14:0] }
			: ((w_op == 4'h3) ? { i_instruction[23:0] }
			: ((w_op == 4'h4) ? { 8'h00, i_instruction[15:0] }
			: (((w_op[3:1]==3'h3)&&(i_instruction[20])) ?
				{ {(8){i_instruction[15]}},i_instruction[15:0] }
			: (((w_op[3:1]==3'h3)&&(~i_instruction[20])) ?
				{ {(4){i_instruction[19]}},i_instruction[19:0] }
			: (i_instruction[20]) ?
				{ {(8){i_instruction[15]}},i_instruction[15:0] }
			:	{ {(4){i_instruction[19]}},i_instruction[19:0] }
			))));
	assign	w_zI = (w_I == 0);

	assign	w_mpy = ((w_op == 4'h4)&&(i_instruction[27:25]!=3'h7));
	assign	w_ldixx = ((w_op == 4'h4)&&(i_instruction[27:24]==4'hf));

	// 4 LUTs
	assign	w_A = { (((w_op==4'h2)&&(~i_gie))?i_instruction[20]:i_gie),
		(w_ldixx)?(i_instruction[19:16]):(i_instruction[27:24])};

	// 1 LUT
	assign	w_B = { (((w_op==4'h2)&&(~i_gie))?i_instruction[15]:i_gie),
			(i_instruction[19:16]) };

	// Don't change the flags on conditional instructions,
	// UNLESS: the conditional instruction was a CMP or TST instruction.
	// 8 LUTs
	assign	w_wF= (w_op[3:1]==3'h0)
			||((i_instruction[23:21]==3'h0)&&((w_op[3])||(w_mpy)));


	always @(posedge i_clk)
		if (i_ce)
		begin
			o_pc <= i_pc +{{(AW-1){1'b0}},1'b1}; // i.e. dcd_pc+1

			// Record what operation we are doing
			o_op <= (w_op == 4'h3) ? 4'h2
				: ((w_op == 4'h4) ?
					((i_instruction[27:24]==4'he) ? 4'h2
					:((i_instruction[27:24]==4'hf) ? 
						(i_instruction[20]? 4'h7:4'h6)
					:(i_instruction[20]? 4'h4:4'h3)))
				: w_op);

			// Default values
			o_A <= {(w_A[3:0]==`CPU_CC_REG),(w_A[3:0]==`CPU_PC_REG),w_A};
			o_B <= {(w_B[3:0]==`CPU_CC_REG),(w_B[3:0]==`CPU_PC_REG),w_B};
			o_M    <= (w_op[3:1] == 3'h3);
			r_I <= w_I;
			o_zI<= w_zI;

			o_wF <= w_wF;

			// 4 LUTs
			o_rA <= (w_op[3:0] != 4'h2)
				&&(w_op[3:0] != 4'h3)
				&&((w_op[3:0] != 4'h4)||(i_instruction[27:24]!=4'he))
				&&(w_op[3:0] != 4'h6);

			// function of 11 bits, -- ugly
			o_rB <= (w_op[3:0] != 4'h3) // Don't read for LDI
				// Don't read for LODxx, NOOP, or MPYxI
				&&((w_op[3:0] != 4'h4)
					||(i_instruction[27:25]!=3'h7)
						&&(i_instruction[19:16]!=4'hf))
				// Always read on MOVE, or when OpB requests it
				&&((w_op[3:0]==4'h2)||(i_instruction[20])
					||(w_op[3:0]==4'h4));

			// Always write back ... unless we are doing a store,
			// CMP/TST, or a NOOP/BREAK
			// 4 LUTs
			o_wR <= (w_op[3:1] != 3'h0)
				&&(w_op[3:0] != 4'h7)
				&&((w_op[3:0] != 4'h4)
					||(i_instruction[27:24] != 4'he));

			o_illegal <= i_illegal;

			// Set the condition under which we do this operation
			// The top four bits are a mask, the bottom four the
			// value the flags must equal once anded with the mask
			o_cond <= (i_instruction[31:28]==4'h3)? 4'h8
				: { (i_instruction[23:21]==3'h0),	
					i_instruction[23:21]};
			casez(i_instruction[31:28])
			4'h2: begin // Move instruction
				end
			4'h3: begin // Load immediate
				o_op <= 4'h2;
				end
			4'h4: begin // Multiply, LDI[HI|LO], or NOOP/BREAK
				if (i_instruction[27:24] == 4'he)
				begin
					// NOOP instruction
					// Might also be a break.  Big
					// instruction set hole here.
					o_illegal <= (i_illegal)||(i_instruction[23:3] != 0);
				end else if (i_instruction[27:24] == 4'hf)
				begin // Load partial immediate(s)
					// o_op <= { 3'h3, instruction[20] };
				end else begin
					// Actual multiply instruction
					// dcdA_rd <= 1'b1;
					// dcdB_rd <= (i_instruction[19:16] != 4'hf);
					// o_op[3:0] <= (i_instruction[20])? 4'h4:4'h3;
				end end
			default: begin
				end
			endcase
			o_gie <= i_gie;
		end

	initial	o_break = 1'b0;
	initial	o_lock  = 1'b0;
	always @(posedge i_clk)
		if (i_ce)
		begin  // 6 LUTs
			o_break <= (i_instruction[31:0] == 32'h4e000001);
			o_lock  <= (i_instruction[31:0] == 32'h4e000002);
		end

	assign	o_I = { {(32-24){r_I[23]}}, r_I};
	assign	o_ALU = (~o_M);
	assign	o_DV  = 1'b0;
	assign	o_FP  = 1'b0;

	always @(posedge i_clk)
		if (i_ce)
		begin
			o_pipe <= (o_valid)&&(i_valid)
				&&(o_M)&&(w_op[3:1] == 3'h3)&&(w_op[0]==o_op[0])
				&&(i_instruction[19:16] == o_B[3:0])
				&&(i_gie == o_gie)
				&&((i_instruction[23:21]==o_cond)
					||(o_cond == 3'h0))
				&&((i_instruction[15:0] == r_I[15:0])
					||(i_instruction[15:0] == (r_I[15:0]+16'h1)));
		end

endmodule
