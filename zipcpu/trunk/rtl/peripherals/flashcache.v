///////////////////////////////////////////////////////////////////////////
//
// Filename:	flashcache.v
//
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:	Since my Zip CPU has primary access to a flash, which requires
//		nearly 24 clock cycles per read, this 'cache' module
//		is offered to minimize the effect.  The CPU may now request
//		some amount of flash to be copied into this on-chip RAM,
//		and then access it with nearly zero latency.
//
// Status:	This file is no longer being used as an active file within
//		the ZipCPU project.  It's an older file from an idea that 
//	never really caught traction.
//
// Interface:
//	FlashCache sits on the Wishbone bus as both a slave and a master.
//	Slave requests for memory will get mapped to a local RAM, from which
//	reads and writes may take place.
//
//	This cache supports a single control register: the base wishbone address
//	of the device to copy memory from.  The bottom bit if this address must
//	be zero (or it will be silently rendered as zero).  When read, this
//	bottom bit will indicate 1) that the controller is still loading memory
//	into the cache, or 0) that the cache is ready to be used.
//
//	Writing to this register will initiate a memory copy from the (new)
//	address.  Once done, the loading bit will be cleared and an interrupt
//	generated.
//
//	Where this memory is placed on the wishbone bus is entirely up to the
//		wishbone bus control logic.  Setting the memory base to an
//		address controlled by this flashcache will produce unusable
//		results, and may well hang the bus.
//	Reads from the memory before complete will return immediately with
//		the value if read address is less than the current copy
//		address, or else they will stall until the read address is
//		less than the copy address.
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
module	flashcache(i_clk,
		// Wishbone contrl interface
		i_wb_cyc, i_wb_stb,i_wb_ctrl_stb, i_wb_we, i_wb_addr, i_wb_data,
			o_wb_ack, o_wb_stall, o_wb_data,
		// Wishbone copy interface
		o_cp_cyc, o_cp_stb, o_cp_we, o_cp_addr, o_cp_data,
			i_cp_ack, i_cp_stall, i_cp_data,
		o_int);
	parameter	LGCACHELEN=10; // 4 kB
	input			i_clk;
	// Control interface, CPU interface to cache
	input			i_wb_cyc, i_wb_stb,i_wb_ctrl_stb, i_wb_we;
	input		[(LGCACHELEN-1):0]	i_wb_addr;
	input		[31:0]	i_wb_data;
	output	reg		o_wb_ack;
	output	wire		o_wb_stall;
	output	wire	[31:0]	o_wb_data;
	// Interface to peripheral bus, including flash
	output	reg		o_cp_cyc, o_cp_stb;
	output	wire		o_cp_we;
	output	reg	[31:0]	o_cp_addr;
	output	wire	[31:0]	o_cp_data;
	input			i_cp_ack, i_cp_stall;
	input		[31:0]	i_cp_data;
	// And an interrupt to send once we complete
	output	reg		o_int;

	reg		loading;
	reg	[31:0]	cache_base;
	reg	[31:0]	cache	[0:((1<<LGCACHELEN)-1)];

	// Decouple writing the cache base from the highly delayed bus lines
	reg		wr_cache_base_flag;
	reg	[31:0]	wr_cache_base_value;
	always @(posedge i_clk)
		wr_cache_base_flag <= ((i_wb_cyc)&&(i_wb_ctrl_stb)&&(i_wb_we));
	always @(posedge i_clk)
		wr_cache_base_value<= { i_wb_data[31:1], 1'b0 };

	initial	cache_base = 32'hffffffff;
	always @(posedge i_clk)
		if (wr_cache_base_flag)
			cache_base <= wr_cache_base_value;

	reg	new_cache_base;
	initial	new_cache_base = 1'b0;
	always @(posedge i_clk)
		if ((wr_cache_base_flag)&&(cache_base != wr_cache_base_value))
			new_cache_base <= 1'b1;
		else
			new_cache_base <= 1'b0;

	reg	[(LGCACHELEN-1):0]	rdaddr;
	initial	loading = 1'b0;
	always @(posedge i_clk)
		if (new_cache_base)
		begin
			loading <= 1'b1;
			o_cp_cyc <= 1'b0;
		end else if ((~o_cp_cyc)&&(loading))
		begin
			o_cp_cyc <= 1'b1;
		end else if (o_cp_cyc)
		begin
			// Handle the ack/read line
			if (i_cp_ack)
			begin
				if (&rdaddr)
				begin
					o_cp_cyc <= 1'b0;
					loading <= 1'b0;
				end
			end
		end
	always @(posedge i_clk)
		if (~o_cp_cyc)
			o_cp_addr <= cache_base;
		else if ((o_cp_cyc)&&(o_cp_stb)&&(~i_cp_stall))
			o_cp_addr <= o_cp_addr + 1;;
	always @(posedge i_clk)
		if ((~o_cp_cyc)&&(loading))
			o_cp_stb  <= 1'b1;
		else if ((o_cp_cyc)&&(o_cp_stb)&&(~i_cp_stall))
		begin
			// We've made our last request
			if (o_cp_addr >= cache_base + { {(32-LGCACHELEN-1){1'b0}}, 1'b1, {(LGCACHELEN){1'b0}}})
				o_cp_stb <= 1'b0;
		end
	always @(posedge i_clk)
		if (~loading)
			rdaddr    <= 0;
		else if ((o_cp_cyc)&&(i_cp_ack))
			rdaddr <= rdaddr + 1;

	initial	o_int = 1'b0;
	always @(posedge i_clk)
		if ((o_cp_cyc)&&(i_cp_ack)&&(&rdaddr))
			o_int <= 1'b1;
		else
			o_int <= 1'b0;

	assign	o_cp_we = 1'b0;
	assign	o_cp_data = 32'h00;


	//
	//	Writes to our cache ... always delayed by a clock.
	//		Clock 0	:	Write request
	//		Clock 1 : 	Write takes place
	//		Clock 2 : 	Available for reading
	//
	reg				we;
	reg	[(LGCACHELEN-1):0]	waddr;
	reg	[31:0]			wval;
	always @(posedge i_clk)
		we <= (loading)?((o_cp_cyc)&&(i_cp_ack)):(i_wb_cyc)&&(i_wb_stb)&&(i_wb_we);
	always @(posedge i_clk)
		waddr <= (loading)?rdaddr:i_wb_addr;
	always @(posedge i_clk)
		wval <= (loading)?i_cp_data:i_wb_data;

	always @(posedge i_clk)
		if (we)
			cache[waddr] <= wval;

	reg	[31:0]	cache_data;
	always @(posedge i_clk)
		if ((i_wb_cyc)&&(i_wb_stb))
			cache_data <= cache[i_wb_addr];

	always @(posedge i_clk)
		o_wb_ack <= (i_wb_cyc)&&(
				((i_wb_stb)&&(~loading))
				||(i_wb_ctrl_stb));
	reg	ctrl;
	always @(posedge i_clk)
		ctrl <= i_wb_ctrl_stb;
	assign	o_wb_data = (ctrl)?({cache_base[31:1],loading}):cache_data;
	assign	o_wb_stall = (loading)&&(~o_wb_ack);

endmodule
