///////////////////////////////////////////////////////////////////////////
//
// Filename:	cpuops_deprecated.v
//
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:	This is the ALU within the Zip CPU.  This particular version,
//		however, has been deprecated in favor of the newer instruction
//	set.  The primary difference is that this instruction set doesn't
//	offer the bit reversal or population count instructions, and the
//	newer ALU reorders the opcodes.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
///////////////////////////////////////////////////////////////////////////
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
///////////////////////////////////////////////////////////////////////////
//
module	cpuops_deprecated(i_clk, i_rst, i_ce, i_valid, i_op, i_a, i_b,
		o_c, o_f, o_valid, o_illegal);
	parameter	IMPLEMENT_MPY = 1;
	input		i_clk, i_rst, i_ce;
	input		[3:0]	i_op;
	input		[31:0]	i_a, i_b;
	input			i_valid;
	output	reg	[31:0]	o_c;
	output	wire	[3:0]	o_f;
	output	reg		o_valid;
	output	wire		o_illegal;

	// Rotate-left pre-logic
	wire	[63:0]	w_rol_tmp;
	assign	w_rol_tmp = { i_a, i_a } << i_b[4:0];
	wire	[31:0]	w_rol_result;
	assign	w_rol_result = w_rol_tmp[63:32]; // Won't set flags

	// Shift register pre-logic
	wire	[32:0]		w_lsr_result, w_asr_result;
	assign	w_asr_result = (|i_b[31:5])? {(33){i_a[31]}}
				: ( {i_a, 1'b0 } >>> (i_b[4:0]) );// ASR
	assign	w_lsr_result = (|i_b[31:5])? 33'h00
				: ( { i_a, 1'b0 } >> (i_b[4:0]) );// LSR


	wire	z, n, v;
	reg	c, pre_sign, set_ovfl;
	always @(posedge i_clk)
		if (i_ce)
			set_ovfl =((((i_op==4'h0)||(i_op==4'h8)) // SUB&CMP
						&&(i_a[31] != i_b[31]))
				||((i_op==4'ha)&&(i_a[31] == i_b[31])) // ADD
				||(i_op == 4'hd) // LSL
				||(i_op == 4'hf)); // LSR


	// A 4-way multiplexer can be done in one 6-LUT.
	// A 16-way multiplexer can therefore be done in 4x 6-LUT's with
	//	the Xilinx multiplexer fabric that follows. 
	// Given that we wish to apply this multiplexer approach to 33-bits,
	// this will cost a minimum of 132 6-LUTs.
	generate
	if (IMPLEMENT_MPY == 0)
	begin
		always @(posedge i_clk)
		if (i_ce)
		begin
			pre_sign <= (i_a[31]);
			c <= 1'b0;
			casez(i_op)
			4'b?000:{c,o_c } <= {1'b0,i_a} - {1'b0,i_b};// CMP/SUB
			4'b?001:   o_c   <= i_a & i_b;		// BTST/And
			// 4'h3: There's a hole here for the unimplemented MPYU,
			// 4'h4: and here for the unimplemented MPYS
			4'h5:      o_c   <= w_rol_result;	// ROL
			4'h6:      o_c   <= { i_a[31:16], i_b[15:0] }; // LODILO
			4'h7:      o_c   <= { i_b[15: 0], i_a[15:0] }; // LODIHI
			4'ha: { c, o_c } <= i_a + i_b;		// Add
			4'hb:      o_c   <= i_a | i_b;		// Or
			4'hc:      o_c   <= i_a ^ i_b;		// Xor
			4'hd: { c, o_c } <= (|i_b[31:5])? 33'h00 : {1'b0, i_a } << i_b[4:0];	// LSL
			4'he: { o_c, c } <= w_asr_result[32:0];	// ASR
			4'hf: { o_c, c } <= w_lsr_result[32:0];	// LSR
			default:   o_c   <=       i_b;		// MOV, LDI
			endcase
		end
	end else begin
		//
		// Multiply pre-logic
		//
		wire	signed	[16:0]	w_mpy_a_input, w_mpy_b_input;
		wire	signed	[33:0]	w_mpy_result;
		assign	w_mpy_a_input = { ((i_a[15])&&(i_op[2])), i_a[15:0] };
		assign	w_mpy_b_input = { ((i_b[15])&&(i_op[2])), i_b[15:0] };
		assign	w_mpy_result  = w_mpy_a_input * w_mpy_b_input;


		//
		// The master ALU case statement
		//
		always @(posedge i_clk)
		if (i_ce)
		begin
			pre_sign <= (i_a[31]);
			c <= 1'b0;
			casez(i_op)
			4'b?000:{c,o_c } <= {1'b0,i_a} - {1'b0,i_b};// CMP/SUB
			4'b?001:   o_c   <= i_a & i_b;		// BTST/And
			4'h3: { c, o_c } <= {1'b0,w_mpy_result[31:0]}; // MPYU
			4'h4: { c, o_c } <= {1'b0,w_mpy_result[31:0]}; // MPYS
			4'h5:      o_c   <= w_rol_result;	// ROL
			4'h6:      o_c   <= { i_a[31:16], i_b[15:0] }; // LODILO
			4'h7:      o_c   <= { i_b[15: 0], i_a[15:0] }; // LODIHI
			4'ha: { c, o_c } <= i_a + i_b;		// Add
			4'hb:      o_c   <= i_a | i_b;		// Or
			4'hc:      o_c   <= i_a ^ i_b;		// Xor
			4'hd: { c, o_c } <= (|i_b[31:5])? 33'h00 : {1'b0, i_a } << i_b[4:0];	// LSL
			4'he: { o_c, c } <= w_asr_result[32:0];	// ASR
			4'hf: { o_c, c } <= w_lsr_result[32:0];	// LSR
			default:   o_c   <=       i_b;		// MOV, LDI
			endcase
		end
	end endgenerate

	generate
	if (IMPLEMENT_MPY == 0)
	begin
		reg	r_illegal;
		always @(posedge i_clk)
			r_illegal <= (i_ce)&&((i_op == 4'h3)||(i_op == 4'h4));
		assign o_illegal = r_illegal;
	end else
		assign o_illegal = 1'b0;
	endgenerate

	assign	z = (o_c == 32'h0000);
	assign	n = (o_c[31]);
	assign	v = (set_ovfl)&&(pre_sign != o_c[31]);

	assign	o_f = { v, n, c, z };

	initial	o_valid = 1'b0;
	always @(posedge i_clk)
		if (i_rst)
			o_valid <= 1'b0;
		else
			o_valid <= (i_ce)&&(i_valid);
endmodule
