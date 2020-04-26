///////////////////////////////////////////////////////////////////////////
//
// Filename:	ziptrap.v
//
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:	On any write, generate an interrupt.  On any read, return
//		the value from the last write.
//
//	This peripheral was added to the Zip System to compensate for the lack
//	of any trap instruction within the Zip instruction set.  Such an 
//	instruction is used heavily by modern operating systems to switch
//	from a user process to a system process.  Since there was no way
//	to build such an interface without a trap instruction, this was added
//	to accomplish that purpose.
//
//	However, in early simulation testing it was discovered that this
//	approach would not be very suitable: the interrupt was not generated
//	the next clock as one would expect.  Hence, executing a trap became:
//
//		TRAP	$5		MOV $TrapAddr, R0
//					LDI $5,R1
//					STO R1,(R0)
//					NOOP
//					NOOP -- here the trap would take effect
//		ADD $5,R6		ADD $5,R6
//
//	This was too cumbersome, necessitating NOOPS and such.  Therefore,
//	the CC register was extended to hold a trap value.  This leads to
//
//		TRAP $5			LDI	$500h,CC
//				; Trap executes immediately, user sees no
//				; delay's, no extra wait instructions.
//		ADD $5,R6		ADD $5,R6
//
//	(BTW: The add is just the "next instruction", whatever that may be.)
//	Note the difference: there's no longer any need to load the trap
//	address into a register (something that usually could not be done with
//	a move, but rather a LDIHI/LDILO pair).  There's no longer any wait
//	for the Wishbone bus, which could've introduced a variable delay.
//	Neither are there any wait states while waiting for the system process
//	to take over and respond.  Oh, and another difference, the new approach
//	no longer requires the system to activate an interrupt line--the user
//	process can always initiate such an interrupt.  Hence, the new
//	solution is better rendering this peripheral obsolete.
//
//	It is maintained here to document this part of the learning process.
//
//
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
module	ziptrap(i_clk,
		i_wb_cyc, i_wb_stb, i_wb_we, i_wb_data,
			o_wb_ack, o_wb_stall, o_wb_data,
		o_int);
	parameter		BW = 32; // Bus width
	input				i_clk;
	// Wishbone inputs
	input				i_wb_cyc, i_wb_stb, i_wb_we;
	input		[(BW-1):0]	i_wb_data;
	// Wishbone outputs
	output	reg			o_wb_ack;
	output	wire			o_wb_stall;
	output	reg	[(BW-1):0]	o_wb_data;
	// Interrupt output
	output	reg			o_int;

	initial	o_wb_ack = 1'b0;
	always @(posedge i_clk)
		o_wb_ack <= ((i_wb_cyc)&&(i_wb_stb));
	assign	o_wb_stall = 1'b0;

	// Initially set to some of bounds value, such as all ones.
	initial	o_wb_data = {(BW){1'b1}};
	always @(posedge i_clk)
		if ((i_wb_cyc)&&(i_wb_stb)&&(i_wb_we))
			o_wb_data <= i_wb_data;

	// Set the interrupt bit on any write.
	initial	o_int = 1'b0;
	always @(posedge i_clk)
		if ((i_wb_cyc)&&(i_wb_stb)&&(i_wb_we))
			o_int <= 1'b1;
		else
			o_int <= 1'b0;

endmodule
