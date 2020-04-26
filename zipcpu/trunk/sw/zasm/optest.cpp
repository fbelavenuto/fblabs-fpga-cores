////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	optest.cpp
//
// Project:	Zip CPU -- a small, lightweight, RISC CPU core
//
// Purpose:	A quick test of whether we can decode opcodes properly.  This
//		test bypasses the assembler, and is useful when the assembler
//	isn't working.  Now that we've got the assembler running, this code
//	isn't nearly as useful anymore.  
//
//	Even more, now that we switched instruction sets, this code is all the
//	more useless ... until updated.
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
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory, run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
#include <stdio.h>

#include "zopcodes.h"

#error	"This file is now obsolete.  The opcodes no longer match the CPU ISET."

void	optest(const ZIPI ins) {
	char	la[80], lb[80];

	zipi_to_string(ins, la, lb);
	printf("0x%08x ->\t%-24s\t%-24s\n", ins, la, lb);
}

int main(int argc, char **argv) {
	char	line[512];

	optest(0x00000000);	// CMP $0,R0
	optest(0x0f000000);	// CMP $0,PC
	optest(0x0e0fffff);	// CMP $-1,CC
	optest(0x2f007fff);	// MOV $-1+R0,PC -> JMP $-1+R0
	optest(0x2f0f7fff);	// MOV $-1+PC,PC -> BRA $-1
	optest(0x2f2f7fff);	// BRZ $-1+R0
	optest(0x2f4fffff);	// MOV.NE $-1+uPC,PC
	optest(0xbe000010);	// HALT
	optest(0xbe000020);	// RTU
	optest(0x9e00005f);	// INT
	optest(0xc6160000);	// CLR R6
	optest(0xcf1f0000);	// CLR R6
	optest(0xce1e0000);	// CLR CC
	optest(0xcd1d0000);	// CLR SP
	optest(0xc71e0000);	// XOR CC,R7
	optest(0x2f0f7fff);	// BRA $-1
	optest(0x2f2f7fff);	// BRZ $-1
	optest(0x2f4f7fff);	// BNE $-1
	optest(0xa0000000);	// ADD $0,R0
	optest(0xaf030350);	// ADD $0x197456,PC -> LJMP $197456+PC
	optest(0xaf230350);	// ADD.Z $0x197456,PC -> LJMP.Z $197456+PC
	optest(0x4e000000);	// NOOP
	optest(0x4f000000);	// LODILO $0,R0
	optest(0x4f00ffff);	// LODILO $0,R0
	optest(0x4f057fff);	// LODILO $0,R5
	optest(0x4f0c0001);	// LODILO $0,R12
	optest(0x4f1d0001);	// LODIHI $0,SP
	optest(0x601f0007);	// LOD ($7+PC),R0
	optest(0x60df000f);	// LOD.C $15(PC),R0
	optest(0x6cff003f);	// LOD.V $63(PC),R12
	optest(0x701f0007);	// STO R0,($7+PC)
	optest(0x70000007);	// STO R0,($7)
	optest(0x701f0000);	// STO R0,(PC)

	optest(0xc0100000);	// CLR R0
	optest(0x21000000);	// MOV R0,R1
	optest(0x22000001);	// MOV $1+$0,R2
	optest(0x23000002);	// MOV $2+$0,R3
	optest(0x24000022);	// MOV $22h+$0,R4
	optest(0x25100377);	// MOV $337h+$0,uR5

}

