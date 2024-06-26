////////////////////////////////////////////////////////////////////////////////
//
// Filename:	zipjiffies.v
//
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:	This peripheral is motivated by the Linux use of 'jiffies'.
//	A process, in Linux, can request to be put to sleep until a certain
//	number of 'jiffies' have elapsed.  Using this interface, the CPU can
//	read the number of 'jiffies' from this peripheral (it only has the
//	one location in address space), add the sleep length to it, and
//	write the result back to the peripheral.  The zipjiffies peripheral
//	will record the value written to it only if it is nearer the current
//	counter value than the last current waiting interrupt time.  If no
//	other interrupts are waiting, and this time is in the future, it will
//	be enabled.  (There is currrently no way to disable a jiffie interrupt
//	once set.)  The processor may then place this sleep request into a
//	list among other sleep requests.  Once the timer expires, it would
//	write the next jiffy request to the peripheral and wake up the process
//	whose timer had expired.
//
//	Quite elementary, really.
//
// Interface:
//	This peripheral contains one register: a counter.  Reads from the
//	register return the current value of the counter.  Writes within
//	the (N-1) bit space following the current time set an interrupt.
//	Writes of values that occurred in the last 2^(N-1) ticks will be
//	ignored.  The timer then interrupts when it's value equals that time. 
//	Multiple writes cause the jiffies timer to select the nearest possible
//	interrupt.  Upon an interrupt, the next interrupt time/value is cleared
//	and will need to be reset if the CPU wants to get notified again.  With
//	only the single interface, there is no way of knowing when the next
//	interrupt is scheduled for, neither is there any way to slow down the
//	interrupt timer in case you don't want it overflowing as often and you
//	wish to wait more jiffies than it supports.  Thus, currently, if you
//	have a timer you wish to wait upon that is more than 2^31 into the
//	future, you would need to set timers along the way, wake up on those
//	timers, and set further timer's until you finally get to your
//	destination.
//
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
module	zipjiffies(i_clk, i_ce,
		i_wb_cyc, i_wb_stb, i_wb_we, i_wb_data,
			o_wb_ack, o_wb_stall, o_wb_data,
		o_int);
	parameter	BW = 32, VW = (BW-2);
	input				i_clk, i_ce;
	// Wishbone inputs
	input				i_wb_cyc, i_wb_stb, i_wb_we;
	input		[(BW-1):0]	i_wb_data;
	// Wishbone outputs
	output	reg			o_wb_ack;
	output	wire			o_wb_stall;
	output	wire	[(BW-1):0]	o_wb_data;
	// Interrupt line
	output	reg			o_int;

	//
	// Our counter logic: The counter is always counting up--it cannot
	// be stopped or altered.  It's really quite simple.  Okay, not quite.
	// We still support the clock enable line.  We do this in order to
	// support debugging, so that if we get everything running inside a
	// debugger, the timer's all slow down so that everything can be stepped
	// together, one clock at a time.
	//
	reg	[(BW-1):0]	r_counter;
	always @(posedge i_clk)
		if (i_ce)
			r_counter <= r_counter+1;

	//
	// Writes to the counter set an interrupt--but only if they are in the
	// future as determined by the signed result of an unsigned subtract.
	//
	reg				int_set,  new_set;
	reg		[(BW-1):0]	int_when, new_when;
	wire	signed	[(BW-1):0]	till_when, till_wb;
	assign	till_when = int_when-r_counter;
	assign	till_wb   = new_when-r_counter;

	initial	new_set = 1'b0;
	always @(posedge i_clk)
		// Delay things by a clock to simplify our logic
		if ((i_wb_cyc)&&(i_wb_stb)&&(i_wb_we))
		begin
			new_set <= 1'b1;
			new_when<= i_wb_data;
		end else
			new_set <= 1'b0;

	initial	o_int   = 1'b0;
	initial	int_set = 1'b0;
	always @(posedge i_clk)
	begin
		o_int <= 1'b0;
		if ((i_ce)&&(int_set)&&(r_counter == int_when))
		begin // Interrupts are self-clearing
			o_int <= 1'b1;	// Set the interrupt flag
			int_set <= 1'b0;// Clear the interrupt
		end

		if ((new_set)&&(till_wb > 0)&&((till_wb<till_when)||(~int_set)))
		begin
			int_when <= new_when;
			int_set <= ((int_set)||(till_wb>0));
		end
	end

	//
	// Acknowledge any wishbone accesses -- everything we did took only
	// one clock anyway.
	//
	always @(posedge i_clk)
		o_wb_ack <= (i_wb_cyc)&&(i_wb_stb);

	assign	o_wb_data = r_counter;
	assign	o_wb_stall = 1'b0;
endmodule
