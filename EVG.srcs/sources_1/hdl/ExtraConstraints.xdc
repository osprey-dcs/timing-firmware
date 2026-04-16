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
connect_debug_port u_ila_0/clk [get_nets [list mgtWrapper_i/txoutclk_bufg_0]]
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
connect_debug_port u_ila_1/clk [get_nets [list bd_i/clk_wiz_1/inst/clk_out1]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
set_property port_width 7 [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {bd_i/ospreyEVG/inst/s_axi_awaddr[0]} {bd_i/ospreyEVG/inst/s_axi_awaddr[1]} {bd_i/ospreyEVG/inst/s_axi_awaddr[2]} {bd_i/ospreyEVG/inst/s_axi_awaddr[3]} {bd_i/ospreyEVG/inst/s_axi_awaddr[4]} {bd_i/ospreyEVG/inst/s_axi_awaddr[5]} {bd_i/ospreyEVG/inst/s_axi_awaddr[6]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
set_property port_width 32 [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list {bd_i/ospreyEVG/inst/s_axi_wdata[0]} {bd_i/ospreyEVG/inst/s_axi_wdata[1]} {bd_i/ospreyEVG/inst/s_axi_wdata[2]} {bd_i/ospreyEVG/inst/s_axi_wdata[3]} {bd_i/ospreyEVG/inst/s_axi_wdata[4]} {bd_i/ospreyEVG/inst/s_axi_wdata[5]} {bd_i/ospreyEVG/inst/s_axi_wdata[6]} {bd_i/ospreyEVG/inst/s_axi_wdata[7]} {bd_i/ospreyEVG/inst/s_axi_wdata[8]} {bd_i/ospreyEVG/inst/s_axi_wdata[9]} {bd_i/ospreyEVG/inst/s_axi_wdata[10]} {bd_i/ospreyEVG/inst/s_axi_wdata[11]} {bd_i/ospreyEVG/inst/s_axi_wdata[12]} {bd_i/ospreyEVG/inst/s_axi_wdata[13]} {bd_i/ospreyEVG/inst/s_axi_wdata[14]} {bd_i/ospreyEVG/inst/s_axi_wdata[15]} {bd_i/ospreyEVG/inst/s_axi_wdata[16]} {bd_i/ospreyEVG/inst/s_axi_wdata[17]} {bd_i/ospreyEVG/inst/s_axi_wdata[18]} {bd_i/ospreyEVG/inst/s_axi_wdata[19]} {bd_i/ospreyEVG/inst/s_axi_wdata[20]} {bd_i/ospreyEVG/inst/s_axi_wdata[21]} {bd_i/ospreyEVG/inst/s_axi_wdata[22]} {bd_i/ospreyEVG/inst/s_axi_wdata[23]} {bd_i/ospreyEVG/inst/s_axi_wdata[24]} {bd_i/ospreyEVG/inst/s_axi_wdata[25]} {bd_i/ospreyEVG/inst/s_axi_wdata[26]} {bd_i/ospreyEVG/inst/s_axi_wdata[27]} {bd_i/ospreyEVG/inst/s_axi_wdata[28]} {bd_i/ospreyEVG/inst/s_axi_wdata[29]} {bd_i/ospreyEVG/inst/s_axi_wdata[30]} {bd_i/ospreyEVG/inst/s_axi_wdata[31]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe2]
set_property port_width 1 [get_debug_ports u_ila_1/probe2]
connect_debug_port u_ila_1/probe2 [get_nets [list bd_i/ospreyEVG/inst/s_axi_awvalid]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe3]
set_property port_width 1 [get_debug_ports u_ila_1/probe3]
connect_debug_port u_ila_1/probe3 [get_nets [list bd_i/ospreyEVG/inst/s_axi_bready]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe4]
set_property port_width 1 [get_debug_ports u_ila_1/probe4]
connect_debug_port u_ila_1/probe4 [get_nets [list bd_i/ospreyEVG/inst/s_axi_bvalid]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe5]
set_property port_width 1 [get_debug_ports u_ila_1/probe5]
connect_debug_port u_ila_1/probe5 [get_nets [list bd_i/ospreyEVG/inst/s_axi_wready]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe6]
set_property port_width 1 [get_debug_ports u_ila_1/probe6]
connect_debug_port u_ila_1/probe6 [get_nets [list bd_i/ospreyEVG/inst/s_axi_wvalid]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe7]
set_property port_width 1 [get_debug_ports u_ila_1/probe7]
connect_debug_port u_ila_1/probe7 [get_nets [list bd_i/ospreyEVG/inst/sysWriteStrobe]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe8]
set_property port_width 1 [get_debug_ports u_ila_1/probe8]
connect_debug_port u_ila_1/probe8 [get_nets [list bd_i/ospreyEVG/inst/writeWaitStateCounter]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe9]
set_property port_width 1 [get_debug_ports u_ila_1/probe9]
connect_debug_port u_ila_1/probe9 [get_nets [list bd_i/ospreyEVG/inst/sysTimerControlToggle]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets sysClk]
