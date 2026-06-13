IVERILOG=iverilog
VVP=vvp

TBs += ospreyRFIN_tb.v

IFLAGS =-g2012 -Wall

IFLAGS+=-y../EVG.srcs/sources_1/hdl

all: $(TBs:%_tb.v=%_tb)

clean:
	rm -f *.d *.d1 *.vvp *.fst

%_tb: %_tb.vvp FORCE
	$(VVP) -M. -N "$<" -fst +vcd="$@.fst"

%_tb.vvp: %_tb.v
	$(IVERILOG) -o "$@" -Mall="$@.d1" $(IFLAGS) $(<_IFLAGS) "$<"
	echo -n "$@ : Makefile " > "$@.d"
	cat "$@.d1" | sort -u | xargs echo >> "$@.d"
	rm "$@.d1"

-include $(wildcard *.d)

FORCE:
.PHONY: all clean
