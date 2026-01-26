TEST_SOURCE = ../../hdl/tinyEVR.v tinyEVR_tb.v
	
all: tinyEVR_tb.vvp

tinyEVR_tb.vvp: $(TEST_SOURCE)
	iverilog -Wall -o tinyEVR_tb.vvp $(TEST_SOURCE)

test: tinyEVR_tb.vvp
	vvp tinyEVR_tb.vvp -fst >test.dat

tinyEVR_tb.fst:  tinyEVR_tb.vvp
	vvp  tinyEVR_tb.vvp -fst >test.dat

view:  tinyEVR_tb.fst force
	-gtkwave tinyEVR_tb.gtkw &

clean:
	rm -f tinyEVR_tb.vvp tinyEVR_tb.fst test.dat

force:
