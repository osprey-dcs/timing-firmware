# Target constraints file -- Extra constraints (Chipscope, etc.)







create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 2048 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list bd_i/latencyMMCM/inst/clk_out1]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 18 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].filter[0]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].filter[1]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].filter[2]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].filter[3]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].filter[4]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].filter[5]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].filter[6]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].filter[7]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].filter[8]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].filter[9]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].filter[10]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].filter[11]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].filter[12]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].filter[13]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].filter[14]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].filter[15]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].filter[16]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].filter[17]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 3 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].smpDoneLeadingZeroCount[0]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].smpDoneLeadingZeroCount[1]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].smpDoneLeadingZeroCount[2]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 14 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].counter[0]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].counter[1]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].counter[2]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].counter[3]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].counter[4]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].counter[5]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].counter[6]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].counter[7]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].counter[8]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].counter[9]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].counter[10]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].counter[11]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].counter[12]} {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].counter[13]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 1 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].active}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].active_d}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].overflow}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].smpDoneStrobe}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {bd_i/ospreyEVG/inst/ospreyEVGlatencyCheck_i/genblk1[0].wasValid}]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets u_ila_0_clk_out1]
