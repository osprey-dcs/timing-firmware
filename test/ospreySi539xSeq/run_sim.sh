#!/bin/sh
# Run the ospreySi539xSeq testbench with Icarus Verilog.
#   ./run_sim.sh        run, print the checks
#   ./run_sim.sh -w     run with waveforms and open them in GTKWave
# Looks for ospreySi539xSeq.v in the repo's hdl folder, or set HDL=/full/path.
set -e
cd "$(dirname "$0")"
for p in "$HDL" ../../EVG.srcs/sources_1/hdl/ospreySi539xSeq.v \
         ../EVG.srcs/sources_1/hdl/ospreySi539xSeq.v ./ospreySi539xSeq.v; do
    if [ -n "$p" ] && [ -f "$p" ]; then HDL=$p; break; fi
done
[ -f "$HDL" ] || { echo "Can't find ospreySi539xSeq.v; set HDL=/full/path/ospreySi539xSeq.v"; exit 1; }
echo "Using $HDL"
iverilog -g2012 -o ospreySi539xSeq_tb.vvp ospreySi539xSeq_tb.v "$HDL" si5394_spi_model.v
if [ "$1" = "-w" ]; then
    vvp -n ospreySi539xSeq_tb.vvp +vcd
    gtkwave ospreySi539xSeq_tb.vcd ospreySi539xSeq_tb.gtkw >/dev/null 2>&1 &
else
    vvp -n ospreySi539xSeq_tb.vvp
fi
