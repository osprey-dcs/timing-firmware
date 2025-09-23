# Target constraints file -- Extra constraints (Chipscope, etc.)






create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list mgtWrapper_i/mgtTxClk]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 2 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {evgTxCharIsK[0]} {evgTxCharIsK[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 16 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {evgTxChars[0]} {evgTxChars[1]} {evgTxChars[2]} {evgTxChars[3]} {evgTxChars[4]} {evgTxChars[5]} {evgTxChars[6]} {evgTxChars[7]} {evgTxChars[8]} {evgTxChars[9]} {evgTxChars[10]} {evgTxChars[11]} {evgTxChars[12]} {evgTxChars[13]} {evgTxChars[14]} {evgTxChars[15]}]]
create_debug_core u_ila_1 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_1]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_1]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_1]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_1]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_1]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_1]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_1]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_1]
set_property port_width 1 [get_debug_ports u_ila_1/clk]
connect_debug_port u_ila_1/clk [get_nets [list {mgtWrapper_i/mgtRxClks[0]}]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
set_property port_width 1 [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {bd_i/ospreyEVR/evrRxCharIsK[1]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
set_property port_width 16 [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list {bd_i/evrRxChars[0]} {bd_i/evrRxChars[1]} {bd_i/evrRxChars[2]} {bd_i/evrRxChars[3]} {bd_i/evrRxChars[4]} {bd_i/evrRxChars[5]} {bd_i/evrRxChars[6]} {bd_i/evrRxChars[7]} {bd_i/evrRxChars[8]} {bd_i/evrRxChars[9]} {bd_i/evrRxChars[10]} {bd_i/evrRxChars[11]} {bd_i/evrRxChars[12]} {bd_i/evrRxChars[13]} {bd_i/evrRxChars[14]} {bd_i/evrRxChars[15]}]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets mgtWrapper_i_n_56]
