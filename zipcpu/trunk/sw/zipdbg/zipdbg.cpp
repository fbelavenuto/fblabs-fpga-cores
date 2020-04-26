///////////////////////////////////////////////////////////////////////////////
//
// Filename:	zipdbg.cpp
//
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:	Provide a simple debugger for the Zip CPU.  This allows you
//		to halt the CPU, examine the registers, and even single step
//	the CPU.  It's not fully functional yet, as I would like to implement
//	breakpoints and the ability to modify registers, but it's a good
//	start.
//
//	Commands while in the debugger are:
//	'r'	- RESET the CPU
//	'g'	- Go.  Release the CPU and exit the debugger.
//	'q'	- Quit.  Leave the debugger, while leaving the CPU halted.
//	's'	- Single Step.  Allows the CPU to advance by one instruction.
//
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Tecnhology, LLC
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
#include <stdlib.h>
#include <signal.h>
#include <time.h>
#include <unistd.h>

#include <ctype.h>
#include <ncurses.h>

// #include "twoc.h"
// #include "qspiflashsim.h"
#include "zopcodes.h"
#include "zparser.h"
#include "devbus.h"
#include "regdefs.h"
// #include "port.h"

// No particular "parameters" need definition or redefinition here.
class	ZIPPY : public DEVBUS {
	typedef	DEVBUS::BUSW	BUSW;
	DEVBUS	*m_fpga;
public:
	ZIPPY(DEVBUS *fpga) : m_fpga(fpga) {}

	void	kill(void) { m_fpga->kill(); }
	void	close(void) { m_fpga->close(); }
	void	writeio(const BUSW a, const BUSW v) { m_fpga->writeio(a, v); }
	BUSW	readio(const BUSW a) { return m_fpga->readio(a); }
	void	readi(const BUSW a, const int len, BUSW *buf) {
		return m_fpga->readi(a, len, buf); }
	void	readz(const BUSW a, const int len, BUSW *buf) {
		return m_fpga->readz(a, len, buf); }
	void	writei(const BUSW a, const int len, const BUSW *buf) {
		return m_fpga->writei(a, len, buf); }
	void	writez(const BUSW a, const int len, const BUSW *buf) {
		return m_fpga->writez(a, len, buf); }
	bool	poll(void) { return m_fpga->poll(); }
	void	usleep(unsigned ms) { m_fpga->usleep(ms); }
	void	wait(void) { m_fpga->wait(); }
	bool	bus_err(void) const { return m_fpga->bus_err(); }
	void	reset_err(void) { m_fpga->reset_err(); }
	void	clear(void) { m_fpga->clear(); }

	void	reset(void) { writeio(R_ZIPCTRL, CPU_RESET|CPU_HALT); }
	void	step(void) { writeio(R_ZIPCTRL, CPU_STEP); }
	void	go(void) { writeio(R_ZIPCTRL, CPU_GO); }
	void	halt(void) {	writeio(R_ZIPCTRL, CPU_HALT); }
	bool	stalled(void) { return ((readio(R_ZIPCTRL)&CPU_STALL)==0); }

	void	showval(int y, int x, const char *lbl, unsigned int v) {
		mvprintw(y,x, "%s: 0x%08x", lbl, v);
	}

	void	dispreg(int y, int x, const char *n, unsigned int v) {
		// 4,4,8,1 = 17 of 20, +3 = 19
		mvprintw(y, x, "%s: 0x%08x", n, v);
	}

	void	showins(int y, const char *lbl,
			const int gie, const unsigned int pc) {
		char	line[80];
		unsigned int	v;

		mvprintw(y, 0, "%s: 0x%08x", lbl, pc);

		if (gie) attroff(A_BOLD);
		else	attron(A_BOLD);

		line[0] = '\0';
		try {
			v= readio(pc);
			zipi_to_string(v, line);
			printw(" 0x%08x", v);
			printw("  %-24s", &line[1]);
		} catch(BUSERR b) {
			printw(" 0x%08x  %-24s", b.addr, "(Bus Error)");
		}
		attroff(A_BOLD);
	}

	unsigned int	cmd_read(unsigned int a) {
		writeio(R_ZIPCTRL, CPU_HALT|(a&0x3f));
		while((readio(R_ZIPCTRL) & CPU_STALL) == 0)
			;
		return readio(R_ZIPDATA);
	}

	void	read_state(void) {
		int	ln= 0;
		bool	gie;

		mvprintw(ln,0, "Peripherals");
		mvprintw(ln,40, "CPU State: ");
		{
			unsigned int v = readio(R_ZIPDATA);
			if (v & 0x010000)
				printw("EXT-INT ");
			if (v & 0x002000)
				printw("Supervisor Mod ");
			if (v & 0x001000)
				printw("Sleeping ");
			if (v & 0x008000)
				printw("Break-Enabled ");
		}
		ln++;
		showval(ln, 1, "PIC ", cmd_read(32+ 0));
		showval(ln,21, "WDT ", cmd_read(32+ 1));
		showval(ln,41, "CACH", cmd_read(32+ 2));
		showval(ln,61, "PIC2", cmd_read(32+ 3));
		ln++;
		showval(ln, 1, "TMRA", cmd_read(32+ 4));
		showval(ln,21, "TMRB", cmd_read(32+ 5));
		showval(ln,41, "TMRC", cmd_read(32+ 6));
		showval(ln,61, "JIF ", cmd_read(32+ 7));

		ln++;
		showval(ln, 1, "UTSK", cmd_read(32+12));
		showval(ln,21, "UMST", cmd_read(32+13));
		showval(ln,41, "UPST", cmd_read(32+14));
		showval(ln,61, "UAST", cmd_read(32+15));

		ln++;
		ln++;
		unsigned int cc = cmd_read(14);
		gie = (cc & 0x020);
		if (gie)
			attroff(A_BOLD);
		else
			attron(A_BOLD);
		mvprintw(ln, 0, "Supervisor Registers");
		ln++;

		dispreg(ln, 1, "sR0 ", cmd_read(0));
		dispreg(ln,21, "sR1 ", cmd_read(1));
		dispreg(ln,41, "sR2 ", cmd_read(2));
		dispreg(ln,61, "sR3 ", cmd_read(3)); ln++;

		dispreg(ln, 1, "sR4 ", cmd_read(4));
		dispreg(ln,21, "sR5 ", cmd_read(5));
		dispreg(ln,41, "sR6 ", cmd_read(6));
		dispreg(ln,61, "sR7 ", cmd_read(7)); ln++;

		dispreg(ln, 1, "sR8 ", cmd_read( 8));
		dispreg(ln,21, "sR9 ", cmd_read( 9));
		dispreg(ln,41, "sR10", cmd_read(10));
		dispreg(ln,61, "sR11", cmd_read(11)); ln++;

		dispreg(ln, 1, "sR12", cmd_read(12));
		dispreg(ln,21, "sSP ", cmd_read(13));

		mvprintw(ln,41, "sCC :%s%s%s%s%s%s%s",
			(cc & 0x040)?"STP":"   ",
			(cc & 0x020)?"GIE":"   ",
			(cc & 0x010)?"SLP":"   ",
			(cc&8)?"V":" ",
			(cc&4)?"N":" ",
			(cc&2)?"C":" ",
			(cc&1)?"Z":" ");
		mvprintw(ln,61, "sPC : 0x%08x", cmd_read(15));
		ln++;

		if (gie)
			attron(A_BOLD);
		else
			attroff(A_BOLD);
		mvprintw(ln, 0, "User Registers"); ln++;
		dispreg(ln, 1, "uR0 ", cmd_read(16));
		dispreg(ln,21, "uR1 ", cmd_read(17));
		dispreg(ln,41, "uR2 ", cmd_read(18));
		dispreg(ln,61, "uR3 ", cmd_read(19)); ln++;

		dispreg(ln, 1, "uR4 ", cmd_read(20));
		dispreg(ln,21, "uR5 ", cmd_read(21));
		dispreg(ln,41, "uR6 ", cmd_read(22));
		dispreg(ln,61, "uR7 ", cmd_read(23)); ln++;

		dispreg(ln, 1, "uR8 ", cmd_read(24));
		dispreg(ln,21, "uR9 ", cmd_read(25));
		dispreg(ln,41, "uR10", cmd_read(26));
		dispreg(ln,61, "uR11", cmd_read(27)); ln++;

		dispreg(ln, 1, "uR12", cmd_read(28));
		dispreg(ln,21, "uSP ", cmd_read(29));
		cc = cmd_read(30);
		mvprintw(ln,41, "uCC :%s%s%s%s%s%s%s",
			(cc&0x040)?"STP":"   ",
			(cc&0x020)?"GIE":"   ",
			(cc&0x010)?"SLP":"   ",
			(cc&8)?"V":" ",
			(cc&4)?"N":" ",
			(cc&2)?"C":" ",
			(cc&1)?"Z":" ");
		mvprintw(ln,61, "uPC : 0x%08x", cmd_read(31));

		attroff(A_BOLD);
		ln+=2;

		ln+=3;
		BUSW pc = cmd_read((gie)?31:15);
		showins(ln, "I ", gie, pc+2); ln++;
		showins(ln, "Dc", gie, pc+1); ln++;
		showins(ln, "Op", gie, pc  ); ln++;
		showins(ln, "Al", gie, pc-1); ln++;
	}
};

DEVBUS	*m_fpga;

int	main(int argc, char **argv) {
//	FPGAOPEN(m_fpga);
	ZIPPY	*zip = new ZIPPY(m_fpga);

	initscr();
	raw();
	noecho();
	keypad(stdscr, true);

	int	chv;
	bool	done = false;

	zip->halt();
	for(int i=0; (i<5)&&(zip->stalled()); i++)
		;
	if (!zip->stalled())
		zip->read_state();
	while(!done) {
		chv = getch();
		switch(chv) {
		case 'g': case 'G':
			m_fpga->writeio(R_ZIPCTRL, CPU_GO);
			// We just released the CPU, so we're now done.
			done = true;
			break;
		case 'q': case 'Q':
			done = true;
			break;
		case 'r': case 'R':
			zip->reset();
			erase();
			break;
		case 's': case 'S':
			zip->step();
			break;
		case ERR:
		default:
			;
		}

		if (zip->stalled())
			erase();
		else
			zip->read_state();
	}

	endwin();
}

