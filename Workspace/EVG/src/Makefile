BEDROCK = ../bedrock
VERILOG_HEADER = ../../../EVG.srcs/sources_1/hdl/gpio.v
EVG_DRIVER_DATA = ../../EVG_platform/hw/drivers/ospreyEVG_v1_0/data
EVR_DRIVER_DATA = ../../EVG_platform/hw/drivers/ospreyEVR_v1_0/data

all: softwareBuildDate.h verilogHeader JSONrom.h

verilogHeader: $(VERILOG_HEADER)

JSONrom.h: create_JSON_ROM.py \
           $(EVG_DRIVER_DATA)/ospreyEVG.py \
           $(EVR_DRIVER_DATA)/ospreyEVR.py
	PYTHONPATH="$(EVG_DRIVER_DATA):$(EVR_DRIVER_DATA):$(PYTHONPATH)" python3 create_JSON_ROM.py >LEEP.json
	python3 "$(BEDROCK)/build_rom.py" -j LEEP.json -c JSONrom.h

softwareBuildDate.h: clockAdjust.c \
                     clockAdjust.h \
                     console.c \
                     console.h \
                     epics.c \
                     epics.h \
                     eyescan.c \
                     eyescan.h \
                     ffs.c \
                     ffs.h \
                     gpio.h \
                     iicFPGA.c \
                     iicFPGA.h \
                     ioSelect.c \
                     ioSelect.h \
                     localPPS.c \
                     localPPS.h \
                     main.c \
                     mgt.c \
                     mgt.h \
                     mgtClkSwitch.c \
                     mgtClkSwitch.h \
                     mmcMailbox.c \
                     mmcMailbox.h \
                     ospreyRFIN.c \
                     ospreyRFIN.h \
                     ntpTime.c \
                     ntpTime.h \
                     platform.c \
                     platform.h \
                     systemParameters.c \
                     systemParameters.h \
                     tftp.c \
                     tftp.h \
                     util.c \
                     util.h \
                     xadc.c \
                     xadc.h \
                     JSONrom.h
	sh setSoftwareBuildDate.sh >softwareBuildDate.h

$(VERILOG_HEADER): gpio.h
	echo "UPDATING VERILOG HEADER -- FIRMWARE MUST BE REBUILT!"
	sh createVerilogHeader.sh "$(VERILOG_HEADER)"

clean:
	rm -rf LEEP.json JSONrom.h
