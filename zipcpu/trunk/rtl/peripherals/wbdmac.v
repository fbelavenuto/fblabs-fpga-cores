////////////////////////////////////////////////////////////////////////////////
//
//
// Filename: 	wbdmac.v
//
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:	Wishbone DMA controller
//
//	This module is controllable via the wishbone, and moves values from
//	one location in the wishbone address space to another.  The amount of
//	memory moved at any given time can be up to 4kB, or equivalently 1kW.
//	Four registers control this DMA controller: a control/status register,
//	a length register, a source WB address and a destination WB address.
//	These register may be read at any time, but they may only be written
//	to when the controller is idle.
//
//	The meanings of three of the setup registers should be self explanatory:
//		- The length register controls the total number of words to
//			transfer.
//		- The source address register controls where the DMA controller
//			reads from.  This address may or may not be incremented
//			after each read, depending upon the setting in the
//			control/status register.
//		- The destination address register, which controls where the DMA
//			controller writes to.  This address may or may not be
//			incremented after each write, also depending upon the
//			setting in the control/status register.
//
//	It is the control/status register, at local address zero, that needs
//	more definition:
//
//	Bits:
//	31	R	Write protect	If this is set to one, it means the
//				write protect bit is set and the controller
//				is therefore idle.  This bit will be set upon
//				completing any transfer.
//	30	R	Error.		The controller stopped mid-transfer
//					after receiving a bus error.
//	29	R/W	inc_s_n		If set to one, the source address
//				will not increment from one read to the next.
//	28	R/W	inc_d_n		If set to one, the destination address
//				will not increment from one write to the next.
//	27	R	Always 0
//	26..16	R	nread		Indicates how many words have been read,
//				and not necessarily written (yet).  This
//				combined with the cfg_len parameter should tell
//				exactly where the controller is at mid-transfer.
//	27..16	W	WriteProtect	When a 12'h3db is written to these
//				bits, the write protect bit will be cleared.
//				
//	15	R/W	on_dev_trigger	When set to '1', the controller will
//				wait for an external interrupt before starting.
//	14..10	R/W	device_id	This determines which external interrupt
//				will trigger a transfer.
//	9..0	R/W	transfer_len	How many bytes to transfer at one time.
//				The minimum transfer length is one, while zero
//				is mapped to a transfer length of 1kW.
//
//
//	To use this, follow this checklist:
//	1. Wait for any prior DMA operation to complete
//		(Read address 0, wait 'till either top bit is set or cfg_len==0)
//	2. Write values into length, source and destination address. 
//		(writei(3, &vals) should be sufficient for this.)
//	3. Enable the DMAC interrupt in whatever interrupt controller is present
//		on the system.
//	4. Write the final start command to the setup/control/status register:
//		Set inc_s_n, inc_d_n, on_dev_trigger, dev_trigger,
//			appropriately for your task
//		Write 12'h3db to the upper word.
//		Set the lower word to either all zeros, or a smaller transfer
//		length if desired.
//	5. wait() for the interrupt and the operation to complete.
//		Prior to completion, number of items successfully transferred
//		be read from the length register.  If the internal buffer is
//		being used, then you can read how much has been read into that
//		buffer by reading from bits 25..16 of this control/status
//		register.
//
// Creator:	Dan Gisselquist
//		Gisselquist Technology, LLC
//
// Copyright:	2015
//
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
///////////////////////////////////////////////////////////////////////////
//
//
module wbdmac(i_clk,
		i_swb_cyc, i_swb_stb, i_swb_we, i_swb_addr, i_swb_data,
			o_swb_ack, o_swb_stall, o_swb_data,
		o_mwb_cyc, o_mwb_stb, o_mwb_we, o_mwb_addr, o_mwb_data,
			i_mwb_ack, i_mwb_stall, i_mwb_data, i_mwb_err,
		i_dev_ints,
		o_interrupt);
	parameter	ADDRESS_WIDTH=32, LGMEMLEN = 10,
			DW=32, LGDV=5,AW=ADDRESS_WIDTH;
	input			i_clk;
	// Slave/control wishbone inputs
	input			i_swb_cyc, i_swb_stb, i_swb_we;
	input	[1:0]		i_swb_addr;
	input	[(DW-1):0]	i_swb_data;
	// Slave/control wishbone outputs
	output	reg		o_swb_ack;
	output	wire		o_swb_stall;
	output	reg [(DW-1):0]	o_swb_data;
	// Master/DMA wishbone control
	output	reg		o_mwb_cyc, o_mwb_stb, o_mwb_we;
	output	reg [(AW-1):0]	o_mwb_addr;
	output	reg [(DW-1):0]	o_mwb_data;
	// Master/DMA wishbone responses from the bus
	input			i_mwb_ack, i_mwb_stall;
	input	[(DW-1):0]	i_mwb_data;
	input			i_mwb_err;
	// The interrupt device interrupt lines
	input	[(DW-1):0]	i_dev_ints;
	// An interrupt to be set upon completion
	output	reg		o_interrupt;
	// Need to release the bus for a higher priority user
	//	This logic had lots of problems, so it is being
	//	removed.  If you want to make sure the bus is available
	//	for a higher priority user, adjust the transfer length
	//	accordingly.
	//
	// input			i_other_busmaster_requests_bus;
	//


	reg			cfg_wp;	// Write protect
	reg			cfg_err;
	reg	[(AW-1):0]	cfg_waddr, cfg_raddr, cfg_len;
	reg [(LGMEMLEN-1):0]	cfg_blocklen_sub_one;
	reg			cfg_incs, cfg_incd;
	reg	[(LGDV-1):0]	cfg_dev_trigger;
	reg			cfg_on_dev_trigger;

	// Single block operations: We'll read, then write, up to a single
	// memory block here.

	reg	[(DW-1):0]	dma_mem	[0:(((1<<LGMEMLEN))-1)];
	reg	[(LGMEMLEN):0]	nread, nwritten, nacks;
	wire	[(AW-1):0]	bus_nacks;
	assign	bus_nacks = { {(AW-LGMEMLEN-1){1'b0}}, nacks };

	initial	o_interrupt = 1'b0;
	initial	o_mwb_cyc   = 1'b0;
	initial	cfg_err     = 1'b0;
	initial	cfg_wp      = 1'b0;
	initial	cfg_len     = {(AW){1'b0}};
	initial	cfg_blocklen_sub_one = {(LGMEMLEN){1'b1}};
	initial	cfg_on_dev_trigger = 1'b0;
	always @(posedge i_clk)
		if ((o_mwb_cyc)&&(o_mwb_we)) // Write cycle
		begin
			if ((o_mwb_stb)&&(~i_mwb_stall))
			begin
				nwritten <= nwritten+1;
				if (nwritten == nread-1)
					// Wishbone interruptus
					o_mwb_stb <= 1'b0;
				else if (cfg_incd) begin
					o_mwb_addr <= o_mwb_addr + 1;
					cfg_waddr  <= cfg_waddr  + 1;
				end
				// o_mwb_data <= dma_mem[nwritten + 1];
			end

			if (i_mwb_err)
			begin
				o_mwb_cyc <= 1'b0;
				cfg_err <= 1'b1;
				cfg_len <= 0;
				nread   <= 0;
			end else if (i_mwb_ack)
			begin
				nacks <= nacks+1;
				cfg_len <= cfg_len - 1;
				if ((nacks+1 == nwritten)&&(~o_mwb_stb))
				begin
					o_mwb_cyc <= 1'b0;
					nread <= 0;
					o_interrupt <= (cfg_len == 1);
					// Turn write protect back on
					cfg_wp    <= 1'b1;
				end
			end
		end else if ((o_mwb_cyc)&&(~o_mwb_we)) // Read cycle
		begin
			if ((o_mwb_stb)&&(~i_mwb_stall))
			begin
				nacks <= nacks+1;
				if ((nacks == {1'b0, cfg_blocklen_sub_one})
					||(bus_nacks <= cfg_len-1))
					// Wishbone interruptus
					o_mwb_stb <= 1'b0;
				else if (cfg_incs) begin
					o_mwb_addr <= o_mwb_addr + 1;
				end
			end

			if (i_mwb_err)
			begin
				o_mwb_cyc <= 1'b0;
				cfg_err <= 1'b1;
				cfg_len <= 0;
				nread <= 0;
			end else if (i_mwb_ack)
			begin
				nread <= nread+1;
				if ((~o_mwb_stb)&&(nread+1 == nacks))
				begin
					o_mwb_cyc <= 1'b0;
					nacks <= 0;
				end
				if (cfg_incs)
					cfg_raddr  <= cfg_raddr  + 1;
				// dma_mem[nread[(LGMEMLEN-1):0]] <= i_mwb_data;
			end
		end else if ((~o_mwb_cyc)&&(nread > 0)&&(~cfg_err))
		begin // Initiate/continue a write cycle
			o_mwb_cyc  <= 1'b1;
			o_mwb_stb  <= 1'b1;
			o_mwb_we   <= 1'b1;
			// o_mwb_data <= dma_mem[0];
			o_mwb_addr <= cfg_waddr;
			// nwritten  <= 0; // Can't set to zero, in case we're
			// nacks     <= 0; //	continuing a cycle
		end else if ((~o_mwb_cyc)&&(nread == 0)&&(cfg_len>0)&&(~cfg_wp)
				&&((~cfg_on_dev_trigger)
					||(i_dev_ints[cfg_dev_trigger])))
		begin // Initiate a read cycle
			o_mwb_cyc <= 1'b1;
			o_mwb_stb <= 1'b1;
			o_mwb_we  <= 1'b0;
			o_mwb_addr<= cfg_raddr;
			nwritten  <= 0;
			nread     <= 0;
			nacks     <= 0;
		end else begin
			o_mwb_cyc  <= 1'b0;
			o_mwb_stb  <= 1'b0;
			o_mwb_we   <= 1'b0;
			o_mwb_addr <= cfg_raddr;
			o_interrupt<= 1'b0;
			nwritten   <= 0;
			if ((i_swb_cyc)&&(i_swb_stb)&&(i_swb_we))
			begin
				cfg_wp <= 1'b1;
				case(i_swb_addr)
				2'b00: begin
					cfg_wp    <= (i_swb_data[27:16]!=12'hfed);
					cfg_blocklen_sub_one
						<= i_swb_data[(LGMEMLEN-1):0]
						+ {(LGMEMLEN){1'b1}};
						// i.e. -1;
					cfg_dev_trigger    <= i_swb_data[14:10];
					cfg_on_dev_trigger <= i_swb_data[15];
					cfg_incs  <= ~i_swb_data[29];
					cfg_incd  <= ~i_swb_data[28];
					cfg_err   <= 1'b0;
					end
				2'b01: cfg_len   <=  i_swb_data[(AW-1):0];
				2'b10: cfg_raddr <=  i_swb_data[(AW-1):0];
				2'b11: cfg_waddr <=  i_swb_data[(AW-1):0];
				endcase
			end
		end

	//
	// This is tricky.  In order for Vivado to consider dma_mem to be a 
	// proper memory, it must have a simple address fed into it.  Hence
	// the read_address (rdaddr) register.  The problem is that this
	// register must always be one greater than the address we actually
	// want to read from, unless we are idling.  So ... the math is touchy.
	//
	reg	[(LGMEMLEN-1):0]	rdaddr;
	always @(posedge i_clk)
		if ((o_mwb_cyc)&&(o_mwb_we)&&(o_mwb_stb)&&(~i_mwb_stall))
			// This would be the normal advance, save that we are
			// already one ahead of nwritten
			rdaddr <= rdaddr + 1; // {{(LGMEMLEN-1){1'b0}},1};
		else if ((~o_mwb_cyc)&&(nread > 0)&&(~cfg_err))
			// Here's where we do our extra advance
			rdaddr <= nwritten[(LGMEMLEN-1):0]+1;
		else if ((~o_mwb_cyc)||(~o_mwb_we))
			rdaddr <= nwritten[(LGMEMLEN-1):0];
	always @(posedge i_clk)
		if ((~o_mwb_cyc)||((o_mwb_we)&&(o_mwb_stb)&&(~i_mwb_stall)))
			o_mwb_data <= dma_mem[rdaddr];
	always @(posedge i_clk)
		if ((o_mwb_cyc)&&(~o_mwb_we)&&(i_mwb_ack))
			dma_mem[nread[(LGMEMLEN-1):0]] <= i_mwb_data;

	always @(posedge i_clk)
		casez(i_swb_addr)
		2'b00: o_swb_data <= {	~cfg_wp, cfg_err,
					~cfg_incs, ~cfg_incd,
					1'b0, nread,
					cfg_on_dev_trigger, cfg_dev_trigger,
					cfg_blocklen_sub_one
					};
		2'b01: o_swb_data <= { {(DW-AW){1'b0}}, cfg_len  };
		2'b10: o_swb_data <= { {(DW-AW){1'b0}}, cfg_raddr};
		2'b11: o_swb_data <= { {(DW-AW){1'b0}}, cfg_waddr};
		endcase

	always @(posedge i_clk)
		if ((i_swb_cyc)&&(i_swb_stb)) // &&(~i_swb_we))
			o_swb_ack <= 1'b1;
		// else if ((i_swb_cyc)&&(i_swb_stb)&&(i_swb_we)&&(~o_mwb_cyc)&&(nread == 0))
		else
			o_swb_ack <= 1'b0;

	assign	o_swb_stall = 1'b0;

endmodule

