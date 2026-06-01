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
connect_debug_port u_ila_0/clk [get_nets [list fiberLinks/mgtWrapper_i/gt5_rxusrclk_in]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 64 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[0]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[1]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[2]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[3]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[4]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[5]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[6]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[7]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[8]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[9]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[10]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[11]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[12]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[13]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[14]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[15]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[16]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[17]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[18]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[19]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[20]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[21]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[22]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[23]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[24]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[25]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[26]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[27]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[28]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[29]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[30]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[31]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[32]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[33]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[34]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[35]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[36]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[37]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[38]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[39]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[40]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[41]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[42]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[43]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[44]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[45]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[46]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[47]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[48]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[49]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[50]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[51]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[52]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[53]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[54]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[55]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[56]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[57]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[58]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[59]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[60]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[61]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[62]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTimestamp[63]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 64 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {mps_i/mpsLocal_i/acqTimestamp[0]} {mps_i/mpsLocal_i/acqTimestamp[1]} {mps_i/mpsLocal_i/acqTimestamp[2]} {mps_i/mpsLocal_i/acqTimestamp[3]} {mps_i/mpsLocal_i/acqTimestamp[4]} {mps_i/mpsLocal_i/acqTimestamp[5]} {mps_i/mpsLocal_i/acqTimestamp[6]} {mps_i/mpsLocal_i/acqTimestamp[7]} {mps_i/mpsLocal_i/acqTimestamp[8]} {mps_i/mpsLocal_i/acqTimestamp[9]} {mps_i/mpsLocal_i/acqTimestamp[10]} {mps_i/mpsLocal_i/acqTimestamp[11]} {mps_i/mpsLocal_i/acqTimestamp[12]} {mps_i/mpsLocal_i/acqTimestamp[13]} {mps_i/mpsLocal_i/acqTimestamp[14]} {mps_i/mpsLocal_i/acqTimestamp[15]} {mps_i/mpsLocal_i/acqTimestamp[16]} {mps_i/mpsLocal_i/acqTimestamp[17]} {mps_i/mpsLocal_i/acqTimestamp[18]} {mps_i/mpsLocal_i/acqTimestamp[19]} {mps_i/mpsLocal_i/acqTimestamp[20]} {mps_i/mpsLocal_i/acqTimestamp[21]} {mps_i/mpsLocal_i/acqTimestamp[22]} {mps_i/mpsLocal_i/acqTimestamp[23]} {mps_i/mpsLocal_i/acqTimestamp[24]} {mps_i/mpsLocal_i/acqTimestamp[25]} {mps_i/mpsLocal_i/acqTimestamp[26]} {mps_i/mpsLocal_i/acqTimestamp[27]} {mps_i/mpsLocal_i/acqTimestamp[28]} {mps_i/mpsLocal_i/acqTimestamp[29]} {mps_i/mpsLocal_i/acqTimestamp[30]} {mps_i/mpsLocal_i/acqTimestamp[31]} {mps_i/mpsLocal_i/acqTimestamp[32]} {mps_i/mpsLocal_i/acqTimestamp[33]} {mps_i/mpsLocal_i/acqTimestamp[34]} {mps_i/mpsLocal_i/acqTimestamp[35]} {mps_i/mpsLocal_i/acqTimestamp[36]} {mps_i/mpsLocal_i/acqTimestamp[37]} {mps_i/mpsLocal_i/acqTimestamp[38]} {mps_i/mpsLocal_i/acqTimestamp[39]} {mps_i/mpsLocal_i/acqTimestamp[40]} {mps_i/mpsLocal_i/acqTimestamp[41]} {mps_i/mpsLocal_i/acqTimestamp[42]} {mps_i/mpsLocal_i/acqTimestamp[43]} {mps_i/mpsLocal_i/acqTimestamp[44]} {mps_i/mpsLocal_i/acqTimestamp[45]} {mps_i/mpsLocal_i/acqTimestamp[46]} {mps_i/mpsLocal_i/acqTimestamp[47]} {mps_i/mpsLocal_i/acqTimestamp[48]} {mps_i/mpsLocal_i/acqTimestamp[49]} {mps_i/mpsLocal_i/acqTimestamp[50]} {mps_i/mpsLocal_i/acqTimestamp[51]} {mps_i/mpsLocal_i/acqTimestamp[52]} {mps_i/mpsLocal_i/acqTimestamp[53]} {mps_i/mpsLocal_i/acqTimestamp[54]} {mps_i/mpsLocal_i/acqTimestamp[55]} {mps_i/mpsLocal_i/acqTimestamp[56]} {mps_i/mpsLocal_i/acqTimestamp[57]} {mps_i/mpsLocal_i/acqTimestamp[58]} {mps_i/mpsLocal_i/acqTimestamp[59]} {mps_i/mpsLocal_i/acqTimestamp[60]} {mps_i/mpsLocal_i/acqTimestamp[61]} {mps_i/mpsLocal_i/acqTimestamp[62]} {mps_i/mpsLocal_i/acqTimestamp[63]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 64 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[0]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[1]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[2]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[3]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[4]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[5]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[6]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[7]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[8]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[9]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[10]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[11]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[12]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[13]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[14]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[15]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[16]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[17]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[18]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[19]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[20]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[21]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[22]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[23]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[24]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[25]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[26]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[27]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[28]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[29]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[30]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[31]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[32]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[33]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[34]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[35]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[36]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[37]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[38]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[39]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[40]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[41]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[42]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[43]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[44]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[45]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[46]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[47]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[48]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[49]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[50]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[51]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[52]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[53]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[54]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[55]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[56]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[57]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[58]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[59]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[60]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[61]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[62]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTimestamp[63]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 8 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/mpsInputs[0]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/mpsInputs[1]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/mpsInputs[2]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/mpsInputs[3]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/mpsInputs[4]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/mpsInputs[5]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/mpsInputs[6]} {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/mpsInputs[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 8 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {mps_i/mpsLocal_i/invert[0]} {mps_i/mpsLocal_i/invert[1]} {mps_i/mpsLocal_i/invert[2]} {mps_i/mpsLocal_i/invert[3]} {mps_i/mpsLocal_i/invert[4]} {mps_i/mpsLocal_i/invert[5]} {mps_i/mpsLocal_i/invert[6]} {mps_i/mpsLocal_i/invert[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 8 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {mps_i/mpsLocal_i/acqPerChannelTripped[0]} {mps_i/mpsLocal_i/acqPerChannelTripped[1]} {mps_i/mpsLocal_i/acqPerChannelTripped[2]} {mps_i/mpsLocal_i/acqPerChannelTripped[3]} {mps_i/mpsLocal_i/acqPerChannelTripped[4]} {mps_i/mpsLocal_i/acqPerChannelTripped[5]} {mps_i/mpsLocal_i/acqPerChannelTripped[6]} {mps_i/mpsLocal_i/acqPerChannelTripped[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 8 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/mpsInputs[0]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/mpsInputs[1]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/mpsInputs[2]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/mpsInputs[3]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/mpsInputs[4]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/mpsInputs[5]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/mpsInputs[6]} {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/mpsInputs[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list mps_i/mpsLocal_i/acqClearTrip]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqClearTrip}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqClearTrip}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/acqTripped}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/acqTripped}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/sysForceTrip}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/sysForceTrip}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list {mps_i/mpsLocal_i/mpsChan[1].mpsLocalChannel_i/trip}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list {mps_i/mpsLocal_i/mpsChan[0].mpsLocalChannel_i/trip}]]
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
connect_debug_port u_ila_1/clk [get_nets [list fiberLinks/mgtWrapper_i/gt7_txusrclk2_in]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
set_property port_width 8 [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {mps_i/mpsLocal_i/mpsTripped[0]} {mps_i/mpsLocal_i/mpsTripped[1]} {mps_i/mpsLocal_i/mpsTripped[2]} {mps_i/mpsLocal_i/mpsTripped[3]} {mps_i/mpsLocal_i/mpsTripped[4]} {mps_i/mpsLocal_i/mpsTripped[5]} {mps_i/mpsLocal_i/mpsTripped[6]} {mps_i/mpsLocal_i/mpsTripped[7]}]]
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
connect_debug_port u_ila_2/clk [get_nets [list bd_i/clk_wiz_1/inst/clk_out1]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_2/probe0]
set_property port_width 8 [get_debug_ports u_ila_2/probe0]
connect_debug_port u_ila_2/probe0 [get_nets [list {mps_i/mpsLocal_i/sysForceTrip[0]} {mps_i/mpsLocal_i/sysForceTrip[1]} {mps_i/mpsLocal_i/sysForceTrip[2]} {mps_i/mpsLocal_i/sysForceTrip[3]} {mps_i/mpsLocal_i/sysForceTrip[4]} {mps_i/mpsLocal_i/sysForceTrip[5]} {mps_i/mpsLocal_i/sysForceTrip[6]} {mps_i/mpsLocal_i/sysForceTrip[7]}]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets sysClk]
