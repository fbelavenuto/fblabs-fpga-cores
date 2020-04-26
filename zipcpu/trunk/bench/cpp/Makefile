################################################################################
#
# Filename:	Makefile
#
# Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
#
# Purpose:	This makefile builds the final verilator simulation of the
#		zipsystem.  Specifically, it builds the final C++ portion
#		of the simulator, and thus the final simulator executable.
#
#		This simulator depends upon the ncurses library.
#
#
# Creator:	Dan Gisselquist, Ph.D.
#		Gisselquist Technology, LLC
#
################################################################################
#
# Copyright (C) 2015, Gisselquist Technology, LLC
#
# This program is free software (firmware): you can redistribute it and/or
# modify it under the terms of  the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# License:	GPL, v3, as defined and found on www.gnu.org,
#		http://www.gnu.org/licenses/gpl.html
#
#
################################################################################
#
all: zippy_tb

CXX	:= g++
FLAGS	:= -Wall -Og -g
ZASM	:= ../../sw/zasm
RTLD	:= ../../rtl
INCS	:= -I$(RTLD)/obj_dir/ -I$(RTLD) -I/usr/share/verilator/include -I$(ZASM)
SOURCES := zippy_tb.cpp memsim.cpp twoc.cpp $(ZASM)/zopcodes.cpp $(ZASM)/zparser.cpp
VLIB	:= /usr/share/verilator/include/verilated.cpp
RAWLIB	:= $(VLIB) $(RTLD)/obj_dir/Vzipsystem__ALL.a
LIBS	:= $(RAWLIB) -lncurses
TESTF	:= $(ZASM)/z.out
DHRYSTONEF := ../asm/zipdhry.z

zippy_tb: $(SOURCES) $(RAWLIB) $(ZASM)/zopcodes.h $(ZASM)/zparser.h testb.h
zippy_tb: $(RTLD)/cpudefs.h
	$(CXX) $(FLAGS) $(INCS) $(SOURCES) $(LIBS) -o $@

div_tb: div_tb.cpp twoc.cpp $(VLIB) $(RTLD)/obj_dir/Vdiv__ALL.a testb.h
	$(CXX) $(FLAGS) $(INCS) div_tb.cpp twoc.cpp $(VLIB) $(RTLD)/obj_dir/Vdiv__ALL.a -o $@

pdump: pdump.cpp $(ZASM)/zopcodes.cpp $(ZASM)/zparser.cpp 
pdump: $(ZASM)/zopcodes.h $(ZASM)/zparser.h testb.h twoc.cpp
	$(CXX) $(FLAGS) $(INCS) pdump.cpp $(ZASM)/zopcodes.cpp $(ZASM)/zparser.cpp twoc.cpp -o $@

.PHONY: stest
stest: zippy_tb
	./zippy_tb -s $(TESTF)

.PHONY: itest
itest: zippy_tb
	./zippy_tb $(TESTF)

.PHONY: test
test: zippy_tb stest
	./zippy_tb -a $(TESTF)

.PHONY: dhrystone
dhrystone: zippy_tb
	./zippy_tb -a $(DHRYSTONEF)

.PHONY: clean
clean:
	rm ./zippy_tb pdump div_tb
