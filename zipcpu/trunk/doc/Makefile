all:	pdftex gpl-3.0.pdf spec.pdf
DSRC := src

gpl-3.0.pdf: $(DSRC)/gpl-3.0.tex
	latex $(DSRC)/gpl-3.0.tex
	latex $(DSRC)/gpl-3.0.tex
	dvips -q -z -t letter -P pdf -o gpl-3.0.ps gpl-3.0.dvi
	ps2pdf -dAutoRotatePages=/All gpl-3.0.ps gpl-3.0.pdf
	rm gpl-3.0.dvi gpl-3.0.log gpl-3.0.aux gpl-3.0.ps

.PHONY: pdftex
pdftex:
	@cd gfx; bash -c "if [[ -e Makefile ]]; then make --no-print-directory; fi"

spec.pdf: $(DSRC)/spec.tex $(DSRC)/gqtekspec.cls $(DSRC)/GT.eps
	cd $(DSRC)/; latex spec.tex
	cd $(DSRC)/; latex spec.tex
	cd $(DSRC)/; dvips -q -z -t letter -P pdf -o ../spec.ps spec.dvi
	ps2pdf -dAutoRotatePages=/All spec.ps spec.pdf
	grep -i warning $(DSRC)/spec.log
	rm $(DSRC)/spec.dvi $(DSRC)/spec.log
	rm $(DSRC)/spec.aux $(DSRC)/spec.toc
	rm $(DSRC)/spec.lot $(DSRC)/spec.lof
	rm $(DSRC)/spec.out spec.ps

zipos.pdf: $(DSRC)/zipos.tex $(DSRC)/gqtekspec.cls $(DSRC)/GT.eps
	cd $(DSRC)/; latex zipos.tex
	cd $(DSRC)/; latex zipos.tex
	cd $(DSRC)/; dvips -q -z -t letter -P pdf -o ../zipos.ps zipos.dvi
	ps2pdf -dAutoRotatePages=/All zipos.ps zipos.pdf
	rm $(DSRC)/zipos.dvi $(DSRC)/zipos.log
	rm $(DSRC)/zipos.aux $(DSRC)/zipos.toc
	rm $(DSRC)/zipos.lot $(DSRC)/zipos.lof
	rm $(DSRC)/zipos.out zipos.ps

