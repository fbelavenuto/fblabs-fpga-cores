///////////////////////////////////////////////////////////////////////////////
//
// Filename:	div.v
//
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:	Provide an Integer divide capability to the Zip CPU.
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
// `include "cpudefs.v"
//
module	div(i_clk, i_rst, i_wr, i_signed, i_numerator, i_denominator,
		o_busy, o_valid, o_err, o_quotient, o_flags);
	parameter	BW=32, LGBW = 5;
	input		i_clk, i_rst;
	// Input parameters
	input			i_wr, i_signed;
	input	[(BW-1):0]	i_numerator, i_denominator;
	// Output parameters
	output	reg		o_busy, o_valid, o_err;
	output	reg [(BW-1):0]	o_quotient;
	output	wire	[3:0]	o_flags;

	reg	[(2*BW-2):0]	r_divisor;
	reg	[(BW-1):0]	r_dividend;
	wire	[(BW):0]	diff; // , xdiff[(BW-1):0];
	assign	diff = r_dividend - r_divisor[(BW-1):0];
	// assign	xdiff= r_dividend - { 1'b0, r_divisor[(BW-1):1] };

	reg		r_sign, pre_sign, r_z, r_c;
	reg	[(LGBW):0]	r_bit;

	always @(posedge i_clk)
		if (i_rst)
		begin
			o_busy <= 1'b0;
		end else if (i_wr)
		begin
			o_busy <= 1'b1;
		end else if ((o_busy)&&((r_bit == 6'h0)||(o_err)))
			o_busy <= 1'b0;
		// else busy is zero and stays at zero

	always @(posedge i_clk)
		if ((i_rst)||(i_wr))
			o_valid <= 1'b0;
		else if (o_busy)
		begin
			if ((r_bit == 6'h0)||(o_err))
				o_valid <= (o_err)||(~r_sign);
		end else if (r_sign)
		begin
			// if (o_err), o_valid is already one.
			// 	if not, o_valid has not yet become one.
			o_valid <= (~o_err); // 1'b1;
		end else
			o_valid <= 1'b0;

	always @(posedge i_clk)
		if((i_rst)||(o_valid))
			o_err <= 1'b0;
		else if (o_busy)
			o_err <= (r_divisor == 0);

	always @(posedge i_clk)
		if (i_wr)
		begin
			o_quotient <= 0;
			// r_bit <= { 1'b1, {(LGBW){1'b0}} };
			r_bit <= { 1'b0, {(LGBW){1'b1}} };
			r_divisor <= {  i_denominator, {(BW-1){1'b0}} };
			r_dividend <=  i_numerator;
			r_sign <= 1'b0;
			pre_sign <= i_signed;
			r_z <= 1'b1;
		end else if (pre_sign)
		begin
			// r_bit <= r_bit - 1;
			r_sign <= ((r_divisor[(2*BW-2)])^(r_dividend[(BW-1)]));;
			if (r_dividend[BW-1])
				r_dividend <= -r_dividend;
			if (r_divisor[(2*BW-2)])
				r_divisor[(2*BW-2):(BW-1)] <= -r_divisor[(2*BW-2):(BW-1)];
			pre_sign <= 1'b0;
		end else if (o_busy)
		begin
			r_bit <= r_bit + {(LGBW+1){1'b1}}; // r_bit = r_bit - 1;
			r_divisor <= { 1'b0, r_divisor[(2*BW-2):1] };
			if (|r_divisor[(2*BW-2):(BW)])
			begin
			end else if (diff[BW])
			begin
			end else begin
				r_dividend <= diff[(BW-1):0];
				o_quotient[r_bit[(LGBW-1):0]] <= 1'b1;
				r_z <= 1'b0;
			end
		end else if (r_sign)
		begin
			r_sign <= 1'b0;
			o_quotient <= -o_quotient;
		end

	// Set Carry on an exact divide
	wire	w_n;
	always @(posedge i_clk)
		r_c <= (o_busy)&&((diff == 0)||(r_dividend == 0));
	assign w_n = o_quotient[(BW-1)];

	assign o_flags = { 1'b0, w_n, r_c, r_z };
endmodule
