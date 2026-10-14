

proc generate {drv_handle} {
    # emit entries for first instance
    #  #define XPAR_OSPREYEVG_ABC
    ::hsi::utils::define_include_file $drv_handle "xparameters.h" "ospreyEVG" "NUM_INSTANCES" \
     "DEVICE_ID"  "C_S_AXI_BASEADDR" "C_S_AXI_HIGHADDR" \
     "TIMER_COUNT" "INPUT_COUNT" "RX_COUNT" "SEQRAM_BANK_COUNT" "SEQRAM_ADDR_WIDTH"

    # emit entries for each instance
    #  #define XPAR_OSPREYEVG_#_ABC
    ::hsi::utils::define_canonical_xpars $drv_handle "xparameters.h" "ospreyEVG" \
     "DEVICE_ID"  "C_S_AXI_BASEADDR" "C_S_AXI_HIGHADDR" \
     "TIMER_COUNT" "INPUT_COUNT" "RX_COUNT" "SEQRAM_BANK_COUNT" "SEQRAM_ADDR_WIDTH"
}
