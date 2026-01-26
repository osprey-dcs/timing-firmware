VIVADO = ${HOME}/Xilinx/2023.1/Vivado/2023.1/data/verilog/src
TEST_SOURCE = ../../hdl/ospreyEVGlatencyCheck.v ospreyEVGlatencyCheck_tb.v
	
all: ospreyEVGlatencyCheck_tb.vvp

ospreyEVGlatencyCheck_tb.vvp: $(TEST_SOURCE)
	iverilog -DSIMULATION -o ospreyEVGlatencyCheck_tb.vvp $(TEST_SOURCE)

test: ospreyEVGlatencyCheck_tb.vvp
	vvp ospreyEVGlatencyCheck_tb.vvp -fst >test.dat

ospreyEVGlatencyCheck_tb.fst:  ospreyEVGlatencyCheck_tb.vvp
	vvp  ospreyEVGlatencyCheck_tb.vvp -fst >test.dat

view:  ospreyEVGlatencyCheck_tb.fst force
	-gtkwave ospreyEVGlatencyCheck_tb.gtkw &

plot:  ospreyEVGlatencyCheck_tb.fst force
	gnuplot plotLatency.gnuplot -

force:

clean:
	rm -f *.vvp *.fst *.dat
