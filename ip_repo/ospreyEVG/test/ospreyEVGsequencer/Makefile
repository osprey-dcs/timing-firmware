TEST_SOURCE = ../../hdl/ospreyEVGsequencer.v ospreyEVGsequencer_tb.v
	
all: ospreyEVGsequencer_tb.vvp

ospreyEVGsequencer_tb.vvp: $(TEST_SOURCE)
	iverilog -o ospreyEVGsequencer_tb.vvp $(TEST_SOURCE)

test: ospreyEVGsequencer_tb.vvp
	vvp ospreyEVGsequencer_tb.vvp -fst >test.dat

ospreyEVGsequencer_tb.fst:  ospreyEVGsequencer_tb.vvp
	vvp  ospreyEVGsequencer_tb.vvp -fst >test.dat

view:  ospreyEVGsequencer_tb.fst force
	-gtkwave ospreyEVGsequencer_tb.gtkw &

force:

clean:
	rm -f *.vvp *.fst *.dat
