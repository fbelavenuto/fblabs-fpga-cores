# SRCS is needed

BARE_SRCS = $(notdir $(SRCS))
BARE_OBJS = $(patsubst %.vhd,%,$(BARE_SRCS))
OBJS = $(addprefix work/, $(BARE_OBJS))

.PHONY: all clean simulation

all: simulation

clean:
	vdel -all work
	$(RM) transcript *.wlf

simulation: work $(OBJS) work/tb
	vsim -t ns tb -do all.do

work:
	vlib work

work/%: %.vht
	vcom $<

define ruletemp
$(patsubst %.vhd, work/%, $(notdir $(1))): $(1)
	vcom $$<
endef

$(foreach src,$(SRCS),$(eval $(call ruletemp, $(src))))
