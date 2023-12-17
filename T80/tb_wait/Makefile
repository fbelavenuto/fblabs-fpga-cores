
#RM = rm -rf
RMDIR = rmdir /s /q
RM = del /q

ENTITIES = t80_pack t80_alu t80_mcode \
    t80_reg t80 t80se tb

WORKS = $(patsubst %, work/%, $(ENTITIES))

.PHONY: all clean simulation

all: simulation

clean:
	$(RM) transcript *.wlf
	$(RMDIR) work

simulation: work $(WORKS)
	vsim -t ns tb -do all.do

work:
	vlib work

work/%: ../%.vhd
	vcom $<

work/%: %.vht
	vcom $<
