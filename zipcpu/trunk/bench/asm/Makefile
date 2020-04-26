################################################################################
#
# Filename:	Makefile
#
# Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
#
# Purpose:	This makefile builds the various assembler level test benches
#		that exist.
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
all: zipdhry.z testdiv.z wdt.z halttest.z zipdhry.txt nullpc.txt poptest.txt
ZDIR := ../../sw/zasm
ZASM := $(ZDIR)/zasm
ZDMP := $(ZDIR)/zdump
LIBS := ../../sw/lib
INCS := -I$(ZDIR)/

dump: zipdhry.txt testdiv.txt

halttest.z: halttest.S 
	$(ZASM) $(INCS) $^ -o $@
zipdhry.z: zipdhry.S $(LIBS)/divs.S $(LIBS)/divu.S stack.S
	$(ZASM) $(INCS) $^ -o $@
zipdhry.txt: zipdhry.z
	$(ZDMP) zipdhry.z > zipdhry.txt

nullpc.z: nullpc.s
	$(ZASM) $(INCS) $^ -o $@
nullpc.txt: nullpc.z
	$(ZDMP) nullpc.z > nullpc.txt

poptest.z: poptest.s
	$(ZASM) $(INCS) $^ -o $@
poptest.txt: poptest.z
	$(ZDMP) poptest.z > poptest.txt

wdt.z: wdt.S
	$(ZASM) $(INCS) $^ -o $@

.PHONY: testdiv
testdiv: testdiv.z
testdiv.z: testdiv.S $(LIBS)/divs.S $(LIBS)/divu.S stack.S
	$(ZASM) $(INCS) $^ -o $@

testdiv.txt: testdiv.z
	$(ZDMP) testdiv.z > testdiv.txt

clean:
	rm -rf *.z zipdhry.txt testdiv.txt
