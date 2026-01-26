TEST_SOURCE = ../../hdl/tinyEVG.v tinyEVG_tb.v
	
all: tinyEVG_tb.vvp

tinyEVG_tb.vvp: $(TEST_SOURCE)
	iverilog -o tinyEVG_tb.vvp $(TEST_SOURCE)

test: tinyEVG_tb.vvp
	vvp tinyEVG_tb.vvp -fst >test.dat

tinyEVG_tb.fst:  tinyEVG_tb.vvp
	vvp  tinyEVG_tb.vvp -fst >test.dat

view:  tinyEVG_tb.fst force
	-gtkwave tinyEVG_tb.gtkw &

force:

clean:
	rm -f *.vvp *.fst *.dat
