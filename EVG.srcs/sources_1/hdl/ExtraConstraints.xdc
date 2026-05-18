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
connect_debug_port u_ila_0/clk [get_nets [list {fiberLinks/mgtWrapper_i/mgtRxClks[0]}]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 16 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/rxChars[0]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/rxChars[1]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/rxChars[2]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/rxChars[3]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/rxChars[4]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/rxChars[5]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/rxChars[6]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/rxChars[7]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/rxChars[8]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/rxChars[9]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/rxChars[10]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/rxChars[11]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/rxChars[12]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/rxChars[13]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/rxChars[14]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/rxChars[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 2 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/rxCharIsK[0]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/rxCharIsK[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 2 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/mgtRxNotInTable[0]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/mgtRxNotInTable[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 2 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/mgtDataIsK[0]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/mgtDataIsK[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 16 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/mgtData[0]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/mgtData[1]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/mgtData[2]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/mgtData[3]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/mgtData[4]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/mgtData[5]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/mgtData[6]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/mgtData[7]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/mgtData[8]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/mgtData[9]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/mgtData[10]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/mgtData[11]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/mgtData[12]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/mgtData[13]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/mgtData[14]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/mgtData[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 6 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/commasNeeded[0]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/commasNeeded[1]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/commasNeeded[2]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/commasNeeded[3]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/commasNeeded[4]} {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/commasNeeded[5]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {fiberLinks/mgtWrapper_i/perLane[0].mgtLinkStatus_i/rxLinkUp}]]
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
connect_debug_port u_ila_1/clk [get_nets [list {fiberLinks/mgtWrapper_i/mgtRxClks[1]}]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
set_property port_width 16 [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/rxChars[0]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/rxChars[1]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/rxChars[2]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/rxChars[3]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/rxChars[4]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/rxChars[5]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/rxChars[6]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/rxChars[7]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/rxChars[8]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/rxChars[9]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/rxChars[10]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/rxChars[11]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/rxChars[12]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/rxChars[13]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/rxChars[14]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/rxChars[15]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
set_property port_width 2 [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/rxCharIsK[0]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/rxCharIsK[1]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe2]
set_property port_width 2 [get_debug_ports u_ila_1/probe2]
connect_debug_port u_ila_1/probe2 [get_nets [list {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/mgtRxNotInTable[0]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/mgtRxNotInTable[1]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe3]
set_property port_width 2 [get_debug_ports u_ila_1/probe3]
connect_debug_port u_ila_1/probe3 [get_nets [list {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/mgtDataIsK[0]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/mgtDataIsK[1]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe4]
set_property port_width 16 [get_debug_ports u_ila_1/probe4]
connect_debug_port u_ila_1/probe4 [get_nets [list {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/mgtData[0]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/mgtData[1]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/mgtData[2]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/mgtData[3]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/mgtData[4]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/mgtData[5]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/mgtData[6]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/mgtData[7]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/mgtData[8]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/mgtData[9]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/mgtData[10]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/mgtData[11]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/mgtData[12]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/mgtData[13]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/mgtData[14]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/mgtData[15]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe5]
set_property port_width 6 [get_debug_ports u_ila_1/probe5]
connect_debug_port u_ila_1/probe5 [get_nets [list {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/commasNeeded[0]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/commasNeeded[1]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/commasNeeded[2]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/commasNeeded[3]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/commasNeeded[4]} {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/commasNeeded[5]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe6]
set_property port_width 1 [get_debug_ports u_ila_1/probe6]
connect_debug_port u_ila_1/probe6 [get_nets [list {fiberLinks/mgtWrapper_i/perLane[1].mgtLinkStatus_i/rxLinkUp}]]
create_debug_core u_ila_2 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_2]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_2]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_2]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_2]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_2]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_2]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_2]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_2]
set_property port_width 1 [get_debug_ports u_ila_2/clk]
connect_debug_port u_ila_2/clk [get_nets [list fiberLinks/mgtWrapper_i/mgtTxClk]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_2/probe0]
set_property port_width 2 [get_debug_ports u_ila_2/probe0]
connect_debug_port u_ila_2/probe0 [get_nets [list {fiberLinks/evsTxCharIsK[0]} {fiberLinks/evsTxCharIsK[1]}]]
create_debug_port u_ila_2 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_2/probe1]
set_property port_width 16 [get_debug_ports u_ila_2/probe1]
connect_debug_port u_ila_2/probe1 [get_nets [list {fiberLinks/evsTxChars[0]} {fiberLinks/evsTxChars[1]} {fiberLinks/evsTxChars[2]} {fiberLinks/evsTxChars[3]} {fiberLinks/evsTxChars[4]} {fiberLinks/evsTxChars[5]} {fiberLinks/evsTxChars[6]} {fiberLinks/evsTxChars[7]} {fiberLinks/evsTxChars[8]} {fiberLinks/evsTxChars[9]} {fiberLinks/evsTxChars[10]} {fiberLinks/evsTxChars[11]} {fiberLinks/evsTxChars[12]} {fiberLinks/evsTxChars[13]} {fiberLinks/evsTxChars[14]} {fiberLinks/evsTxChars[15]}]]
create_debug_core u_ila_3 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_3]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_3]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_3]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_3]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_3]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_3]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_3]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_3]
set_property port_width 1 [get_debug_ports u_ila_3/clk]
connect_debug_port u_ila_3/clk [get_nets [list bd_i/clk_wiz_1/inst/clk_out1]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_3/probe0]
set_property port_width 2 [get_debug_ports u_ila_3/probe0]
connect_debug_port u_ila_3/probe0 [get_nets [list {fiberLinks/mgtWrapper_i/perLane[0].rxResetState[0]} {fiberLinks/mgtWrapper_i/perLane[0].rxResetState[1]}]]
create_debug_port u_ila_3 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_3/probe1]
set_property port_width 2 [get_debug_ports u_ila_3/probe1]
connect_debug_port u_ila_3/probe1 [get_nets [list {fiberLinks/mgtWrapper_i/perLane[1].rxResetState[0]} {fiberLinks/mgtWrapper_i/perLane[1].rxResetState[1]}]]
create_debug_port u_ila_3 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_3/probe2]
set_property port_width 1 [get_debug_ports u_ila_3/probe2]
connect_debug_port u_ila_3/probe2 [get_nets [list {fiberLinks/mgtWrapper_i/perLane[0].rxResetApplyDone}]]
create_debug_port u_ila_3 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_3/probe3]
set_property port_width 1 [get_debug_ports u_ila_3/probe3]
connect_debug_port u_ila_3/probe3 [get_nets [list {fiberLinks/mgtWrapper_i/perLane[0].rxResetAwaitDone}]]
create_debug_port u_ila_3 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_3/probe4]
set_property port_width 1 [get_debug_ports u_ila_3/probe4]
connect_debug_port u_ila_3/probe4 [get_nets [list {fiberLinks/mgtWrapper_i/perLane[0].rxResetLinkUp}]]
create_debug_port u_ila_3 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_3/probe5]
set_property port_width 1 [get_debug_ports u_ila_3/probe5]
connect_debug_port u_ila_3/probe5 [get_nets [list {fiberLinks/mgtWrapper_i/perLane[1].rxResetApplyDone}]]
create_debug_port u_ila_3 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_3/probe6]
set_property port_width 1 [get_debug_ports u_ila_3/probe6]
connect_debug_port u_ila_3/probe6 [get_nets [list {fiberLinks/mgtWrapper_i/perLane[1].rxResetAwaitDone}]]
create_debug_port u_ila_3 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_3/probe7]
set_property port_width 1 [get_debug_ports u_ila_3/probe7]
connect_debug_port u_ila_3/probe7 [get_nets [list {fiberLinks/mgtWrapper_i/perLane[1].rxResetLinkUp}]]
create_debug_port u_ila_3 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_3/probe8]
set_property port_width 1 [get_debug_ports u_ila_3/probe8]
connect_debug_port u_ila_3/probe8 [get_nets [list PMOD2_3_IBUF]]
create_debug_port u_ila_3 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_3/probe9]
set_property port_width 1 [get_debug_ports u_ila_3/probe9]
connect_debug_port u_ila_3/probe9 [get_nets [list PMOD2_0_IBUF]]
create_debug_port u_ila_3 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_3/probe10]
set_property port_width 1 [get_debug_ports u_ila_3/probe10]
connect_debug_port u_ila_3/probe10 [get_nets [list PMOD2_4_IBUF]]
create_debug_port u_ila_3 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_3/probe11]
set_property port_width 1 [get_debug_ports u_ila_3/probe11]
connect_debug_port u_ila_3/probe11 [get_nets [list PMOD2_5_IBUF]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets sysClk]
