VIVADO = ${HOME}/Xilinx/2023.1/Vivado/2023.1/data/verilog/src

TEST_SOURCE = ../../hdl/ospreyEVRoutputDriver.v \
              ospreyEVRoutputDriver_tb.v \
              $(VIVADO)/glbl.v
	
all: ospreyEVRoutputDriver_1_tb.vvp ospreyEVRoutputDriver_8_tb.vvp

ospreyEVRoutputDriver_1_tb.vvp: $(TEST_SOURCE)
	iverilog -PospreyEVRoutputDriver_tb.SERDES_FACTOR=1 -Wall -y "$(VIVADO)/unisims" -o ospreyEVRoutputDriver_1_tb.vvp $(TEST_SOURCE)

ospreyEVRoutputDriver_8_tb.vvp: $(TEST_SOURCE)
	iverilog -PospreyEVRoutputDriver_tb.SERDES_FACTOR=8 -Wall -y "$(VIVADO)/unisims" -o ospreyEVRoutputDriver_8_tb.vvp $(TEST_SOURCE)

test: ospreyEVRoutputDriver_1_tb.vvp ospreyEVRoutputDriver_8_tb.vvp
	vvp ospreyEVRoutputDriver_1_tb.vvp -fst >test_1.dat
	mv ospreyEVRoutputDriver_tb.fst ospreyEVRoutputDriver_1_tb.fst
	vvp ospreyEVRoutputDriver_8_tb.vvp -fst >test_8.dat
	mv ospreyEVRoutputDriver_tb.fst ospreyEVRoutputDriver_8_tb.fst

view: ospreyEVRoutputDriver_1_tb.fst ospreyEVRoutputDriver_8_tb.fst force
	-gtkwave ospreyEVRoutputDriver_1_tb.gtkw &
	-gtkwave ospreyEVRoutputDriver_8_tb.gtkw &

force:

clean:
	rm -f *.vvp *.fst *.dat
	rm -f *.vvp *.fst *.dat
