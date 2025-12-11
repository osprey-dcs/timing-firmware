MMI = ../../../EVG.runs/impl_1/EVG.mmi
BIT = ../../../EVG.runs/impl_1/EVG.bit
IMAGE = EVG.bit

ELF = ../Release/EVG.elf

.PHONY: srCheck elfCheck

all: srcCheck elfCheck $(IMAGE)

srcCheck:
	cd ../src ; make

elfCheck:
	cd ../Release ; make all

$(IMAGE): $(MMI) $(BIT) $(ELF)
	updatemem -force \
              -out "$(IMAGE)" \
              -meminfo "$(MMI)" \
              -bit "$(BIT)" \
              -proc bd_i/microblaze_0 \
              -data "$(ELF)"

clean:
	rm -f vitis_pid*.str *.jou *.log chk*.bin

realclean: clean
