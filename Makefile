
# friendly name for final bit stream using git commit date and hash
# "20261006-0b230ec"
CNAME:=$(shell git log -n1 --format=format:%cd-%h --date=format:%Y%m%d HEAD)

# source for generation by IP packager
IP_SRC:=$(shell git ls-files EVG.srcs/sources_1/bd/bd/ EVG.srcs/sources_1/ip/mgt/ ip_repo)

# source for vivado
HDL_SRC:=$(shell git ls-files EVG.srcs/sources_1/hdl/)

# source for vitis
APP_SRC:=$(shell git ls-files Workspace/)

all: EVG-$(CNAME).bit
everything: all

clean:
	# vivado debris
	rm -rf EVG.gen EVG.cache EVG.hw EVG.runs
	# vitis debris
	rm -rf Workspace/.metadata Workspace/EVG_platform Workspace/EVG_app

.PHONY: all everything clean

# step 1.1: instantiate IP from iprepo/
EVG.gen/sources_1/bd/bd/hdl/bd_wrapper.v: $(IP_SRC)
	rm -rf EVG.gen/sources_1/bd/bd
	rm -rf EVG.gen/sources_1/ip/mgt EVG.runs/mgt_*
	vivado -mode batch -source BuildScripts/PrepareFirmware.tcl
	touch --no-create $@

# step 1.2: Generate special verilog header
EVG.srcs/sources_1/hdl/gpio.v: \
	Workspace/EVG/src/config.h \
	Workspace/EVG/src/gpio.h
	$(MAKE) -C Workspace/EVG/src verilogHeader

# step 2: primary synth and bit stream creation (the slow part)
EVG.xsa: $(HDL_SRC) \
	EVG.srcs/sources_1/hdl/gpio.v \
	EVG.gen/sources_1/bd/bd/hdl/bd_wrapper.v
	vivado -mode batch -source BuildScripts/BuildFirmware.tcl
	touch --no-create $@

# step 3: Generate BSP and build ublaze application
Workspace/EVG_app/Release/EVG_app.elf: EVG.xsa $(APP_SRC)
	rm -rf Workspace/.metadata Workspace/EVG_platform Workspace/EVG_app
	xsct BuildScripts/BuildApp.tcl
	touch --no-create $@

# step 4: add ublaze application info primary bit stream
Workspace/EVG/build/EVG.bit: Workspace/EVG_app/Release/EVG_app.elf
	$(MAKE) -C Workspace/EVG/build EVG.bit ELF=../../EVG_app/Release/EVG_app.elf

# step 5: give final bit stream  a friendly name
EVG-$(CNAME).bit: Workspace/EVG/build/EVG.bit
	cp $< $@

PRINT.%:
	@echo "$* = $($*)"

.PHONY: PRINT.%
