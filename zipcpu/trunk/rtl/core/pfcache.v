////////////////////////////////////////////////////////////////////////////////
//
// Filename:	pfcache.v
//
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:	Keeping our CPU fed with instructions, at one per clock and
//		with no stalls.  An unusual feature of this cache is the
//	requirement that the entire cache may be cleared (if necessary).
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
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
////////////////////////////////////////////////////////////////////////////////
//
module	pfcache(i_clk, i_rst, i_new_pc, i_clear_cache,
			// i_early_branch, i_from_addr,
			i_stall_n, i_pc, o_i, o_pc, o_v,
		o_wb_cyc, o_wb_stb, o_wb_we, o_wb_addr, o_wb_data,
			i_wb_ack, i_wb_stall, i_wb_err, i_wb_data,
			o_illegal);
	parameter	LGCACHELEN = 8, ADDRESS_WIDTH=24,
			CACHELEN=(1<<LGCACHELEN), BUSW=32, AW=ADDRESS_WIDTH,
			CW=LGCACHELEN, PW=LGCACHELEN-5;
	input				i_clk, i_rst, i_new_pc;
	input				i_clear_cache;
	input				i_stall_n;
	input		[(AW-1):0]	i_pc;
	output	reg	[(BUSW-1):0]	o_i;
	output	reg	[(AW-1):0]	o_pc;
	output	wire			o_v;
	//
	output	reg		o_wb_cyc, o_wb_stb;
	output	wire		o_wb_we;
	output	reg	[(AW-1):0]	o_wb_addr;
	output	wire	[(BUSW-1):0]	o_wb_data;
	//
	input				i_wb_ack, i_wb_stall, i_wb_err;
	input		[(BUSW-1):0]	i_wb_data;
	//
	output	reg			o_illegal;

	// Fixed bus outputs: we read from the bus only, never write.
	// Thus the output data is ... irrelevant and don't care.  We set it
	// to zero just to set it to something.
	assign	o_wb_we = 1'b0;
	assign	o_wb_data = 0;

	reg			r_v;
	(* ram_style = "distributed" *)
	reg	[(BUSW-1):0]	cache	[0:((1<<CW)-1)];
	reg	[(AW-CW-1):0]	tags	[0:((1<<(CW-PW))-1)];
	reg	[((1<<(CW-PW))-1):0]	vmask;

	reg	[(AW-1):0]	lastpc;
	reg	[(CW-1):0]	rdaddr;
	reg	[(AW-1):CW]	tagval;
	wire	[(AW-1):PW]	lasttag;
	reg			illegal_valid;
	reg	[(AW-1):PW]	illegal_cache;

	initial	o_i = 32'h76_00_00_00;	// A NOOP instruction
	initial	o_pc = 0;
	always @(posedge i_clk)
		if (~r_v)
		begin
			o_i <= cache[lastpc[(CW-1):0]];
			o_pc <= lastpc;
		end else if ((i_stall_n)||(i_new_pc))
		begin
			o_i <= cache[i_pc[(CW-1):0]];
			o_pc <= i_pc;
		end

	initial	tagval = 0;
	always @(posedge i_clk)
		// It may be possible to recover a clock once the cache line
		// has been filled, but our prior attempt to do so has lead
		// to a race condition, so we keep this logic simple.
		if (((r_v)&&(i_stall_n))||(i_clear_cache)||(i_new_pc))
			tagval <= tags[i_pc[(CW-1):PW]];
		else
			tagval <= tags[lastpc[(CW-1):PW]];

	// i_pc will only increment when everything else isn't stalled, thus
	// we can set it without worrying about that.   Doing this enables
	// us to work in spite of stalls.  For example, if the next address
	// isn't valid, but the decoder is stalled, get the next address
	// anyway.
	initial	lastpc = 0;
	always @(posedge i_clk)
		if (((r_v)&&(i_stall_n))||(i_clear_cache)||(i_new_pc))
			lastpc <= i_pc;

	assign	lasttag = lastpc[(AW-1):PW];
	// initial	lasttag = 0;
	// always @(posedge i_clk)
		// if (((r_v)&&(i_stall_n))||(i_clear_cache)||(i_new_pc))
			// lasttag <= i_pc[(AW-1):PW];

	wire	r_v_from_pc, r_v_from_last;
	assign	r_v_from_pc = ((i_pc[(AW-1):PW] == lasttag)
				&&(tagval == i_pc[(AW-1):CW])
				&&(vmask[i_pc[(CW-1):PW]]));
	assign	r_v_from_last = (
				//(lastpc[(AW-1):PW] == lasttag)&&
				(tagval == lastpc[(AW-1):CW])
				&&(vmask[lastpc[(CW-1):PW]]));

	reg	[1:0]	delay;

	initial	delay = 2'h3;
	initial	r_v = 1'b0;
	always @(posedge i_clk)
		if ((i_rst)||(i_clear_cache)||(i_new_pc)||((r_v)&&(i_stall_n)))
		begin
			r_v <= r_v_from_pc;
			delay <= 2'h2;
		end else if (~r_v) begin // Otherwise, r_v was true and we were
			r_v <= r_v_from_last;	// stalled, hence only if ~r_v
			if (o_wb_cyc)
				delay <= 2'h2;
			else if (delay != 0)
				delay <= delay + 2'b11; // i.e. delay -= 1;
		end

	assign	o_v = (r_v)&&(~i_new_pc);


	initial	o_wb_cyc  = 1'b0;
	initial	o_wb_stb  = 1'b0;
	initial	o_wb_addr = {(AW){1'b0}};
	initial	rdaddr    = 0;
	always @(posedge i_clk)
		if ((i_rst)||(i_clear_cache))
		begin
			o_wb_cyc <= 1'b0;
			o_wb_stb <= 1'b0;
		end else if (o_wb_cyc)
		begin
			if (i_wb_err)
				o_wb_stb <= 1'b0;
			else if ((o_wb_stb)&&(~i_wb_stall))
			begin
				if (o_wb_addr[(PW-1):0] == {(PW){1'b1}})
					o_wb_stb <= 1'b0;
				else
					o_wb_addr[(PW-1):0] <= o_wb_addr[(PW-1):0]+1;
			end

			if (i_wb_ack)
			begin
				rdaddr <= rdaddr + 1;
				tags[o_wb_addr[(CW-1):PW]] <= o_wb_addr[(AW-1):CW];
			end

			if (((i_wb_ack)&&(rdaddr[(PW-1):0]=={(PW){1'b1}}))||(i_wb_err))
				o_wb_cyc <= 1'b0;

			// else if (rdaddr[(PW-1):1] == {(PW-1){1'b1}})
			//	tags[lastpc[(CW-1):PW]] <= lastpc[(AW-1):CW];

		end else if ((~r_v)&&(delay==0)
			&&((tagval != lastpc[(AW-1):CW])
				||(~vmask[lastpc[(CW-1):PW]]))
			&&((~illegal_valid)||(lastpc[(AW-1):PW] != illegal_cache)))
		begin
			o_wb_cyc  <= 1'b1;
			o_wb_stb  <= 1'b1;
			o_wb_addr <= { lastpc[(AW-1):PW], {(PW){1'b0}} };
			rdaddr <= { lastpc[(CW-1):PW], {(PW){1'b0}} };
		end

	// Can't initialize an array, so leave cache uninitialized
	always @(posedge i_clk)
		if ((o_wb_cyc)&&(i_wb_ack))
			cache[rdaddr] <= i_wb_data;

	// VMask ... is a section loaded?
	initial	vmask = 0;
	always @(posedge i_clk)
		if ((i_rst)||(i_clear_cache))
			vmask <= 0;
		else begin
			if ((o_wb_cyc)&&(i_wb_ack)&&(rdaddr[(PW-1):0] == {(PW){1'b1}}))
				vmask[rdaddr[(CW-1):PW]] <= 1'b1;
			if ((~r_v)&&(tagval != lastpc[(AW-1):CW])&&(delay == 0))
				vmask[lastpc[(CW-1):PW]] <= 1'b0;
		end

	initial	illegal_cache = 0;
	initial	illegal_valid = 0;
	always @(posedge i_clk)
		if ((i_rst)||(i_clear_cache))
		begin
			illegal_cache <= 0;
			illegal_valid <= 0;
		end else if ((o_wb_cyc)&&(i_wb_err))
		begin
			illegal_cache <= o_wb_addr[(AW-1):PW];
			illegal_valid <= 1'b1;
		end

	initial o_illegal = 1'b0;
	always @(posedge i_clk)
		if ((i_rst)||(i_clear_cache))
			o_illegal <= 1'b0;
		else
			o_illegal <= (illegal_valid)
				&&(illegal_cache == i_pc[(AW-1):PW]);

endmodule
