IVERILOG=iverilog
VVP=vvp

TBs += ospreyEVG/ospreyEVG_tb.v

IFLAGS =-g2012 -Wall

IFLAGS+=-l../hdl/ospreyEVG.v -yospreyEVG -y../hdl

all: $(TBs:%.v=%_axi0)
all: $(TBs:%.v=%_axi1)

clean:
	rm -f *.d *.d1 *.vvp *.fst

%_axi0: %.vvp FORCE
	$(VVP) -M. -N "$<" -fst +vcd="$@.fst" +axiproto=0

%_axi1: %.vvp FORCE
	$(VVP) -M. -N "$<" -fst +vcd="$@.fst" +axiproto=1

%.vvp: %.v
	$(IVERILOG) -o "$@" -Mall="$@.d1" $(IFLAGS) $(<_IFLAGS) "$<"
	echo -n "$@ : Makefile " > "$@.d"
	cat "$@.d1" | sort -u | xargs echo >> "$@.d"
	rm "$@.d1"

-include $(wildcard *.d)

FORCE:
.PHONY: all clean
