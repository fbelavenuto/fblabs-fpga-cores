#!/bin/bash

export GSFLAGS="-q -dNOPAUSE -sDEVICE=png16m -dGraphicsAlphaBits=4 -dTextAlphaBits=4"
gs $GSFLAGS -g640x480 -sOutputFile=cpu.png -r60 -- cpu.eps
convert cpu.png -trim cpu.png
gs $GSFLAGS -g720x520 -sOutputFile=system.png -r80 -- system.eps
convert system.png -trim system.png
gs $GSFLAGS -g640x480 -sOutputFile=regset.png -r60 -- regset.eps
convert regset.png -trim regset.png
gs $GSFLAGS -g640x480 -sOutputFile=zipbones.png -r80 -- zipbones.eps
convert zipbones.png -trim zipbones.png
