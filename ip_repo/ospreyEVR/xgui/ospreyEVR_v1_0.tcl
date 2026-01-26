# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "C_S_AXI_DATA_WIDTH" -parent ${Page_0} -widget comboBox
  ipgui::add_param $IPINST -name "C_S_AXI_ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_S_AXI_BASEADDR" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_S_AXI_HIGHADDR" -parent ${Page_0}

  ipgui::add_param $IPINST -name "DISTRIBUTED_BUFFER_ADDR_WIDTH"
  ipgui::add_param $IPINST -name "DEBUG"
  set HARDWARE_OUTPUT_COUNT [ipgui::add_param $IPINST -name "HARDWARE_OUTPUT_COUNT"]
  set_property tooltip {Number of hardware output pins} ${HARDWARE_OUTPUT_COUNT}

}

proc update_PARAM_VALUE.ACTION_STROBES_WIDTH { PARAM_VALUE.ACTION_STROBES_WIDTH } {
	# Procedure called to update ACTION_STROBES_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ACTION_STROBES_WIDTH { PARAM_VALUE.ACTION_STROBES_WIDTH } {
	# Procedure called to validate ACTION_STROBES_WIDTH
	return true
}

proc update_PARAM_VALUE.DEBUG { PARAM_VALUE.DEBUG } {
	# Procedure called to update DEBUG when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DEBUG { PARAM_VALUE.DEBUG } {
	# Procedure called to validate DEBUG
	return true
}

proc update_PARAM_VALUE.DISTRIBUTED_BUFFER_ADDR_WIDTH { PARAM_VALUE.DISTRIBUTED_BUFFER_ADDR_WIDTH } {
	# Procedure called to update DISTRIBUTED_BUFFER_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DISTRIBUTED_BUFFER_ADDR_WIDTH { PARAM_VALUE.DISTRIBUTED_BUFFER_ADDR_WIDTH } {
	# Procedure called to validate DISTRIBUTED_BUFFER_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.HARDWARE_OUTPUT_COUNT { PARAM_VALUE.HARDWARE_OUTPUT_COUNT } {
	# Procedure called to update HARDWARE_OUTPUT_COUNT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.HARDWARE_OUTPUT_COUNT { PARAM_VALUE.HARDWARE_OUTPUT_COUNT } {
	# Procedure called to validate HARDWARE_OUTPUT_COUNT
	return true
}

proc update_PARAM_VALUE.C_S_AXI_DATA_WIDTH { PARAM_VALUE.C_S_AXI_DATA_WIDTH } {
	# Procedure called to update C_S_AXI_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_DATA_WIDTH { PARAM_VALUE.C_S_AXI_DATA_WIDTH } {
	# Procedure called to validate C_S_AXI_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.C_S_AXI_ADDR_WIDTH { PARAM_VALUE.C_S_AXI_ADDR_WIDTH } {
	# Procedure called to update C_S_AXI_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_ADDR_WIDTH { PARAM_VALUE.C_S_AXI_ADDR_WIDTH } {
	# Procedure called to validate C_S_AXI_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.C_S_AXI_BASEADDR { PARAM_VALUE.C_S_AXI_BASEADDR } {
	# Procedure called to update C_S_AXI_BASEADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_BASEADDR { PARAM_VALUE.C_S_AXI_BASEADDR } {
	# Procedure called to validate C_S_AXI_BASEADDR
	return true
}

proc update_PARAM_VALUE.C_S_AXI_HIGHADDR { PARAM_VALUE.C_S_AXI_HIGHADDR } {
	# Procedure called to update C_S_AXI_HIGHADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_HIGHADDR { PARAM_VALUE.C_S_AXI_HIGHADDR } {
	# Procedure called to validate C_S_AXI_HIGHADDR
	return true
}


proc update_MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH { MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH PARAM_VALUE.C_S_AXI_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXI_DATA_WIDTH}] ${MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH { MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH PARAM_VALUE.C_S_AXI_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.DISTRIBUTED_BUFFER_ADDR_WIDTH { MODELPARAM_VALUE.DISTRIBUTED_BUFFER_ADDR_WIDTH PARAM_VALUE.DISTRIBUTED_BUFFER_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DISTRIBUTED_BUFFER_ADDR_WIDTH}] ${MODELPARAM_VALUE.DISTRIBUTED_BUFFER_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.DEBUG { MODELPARAM_VALUE.DEBUG PARAM_VALUE.DEBUG } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DEBUG}] ${MODELPARAM_VALUE.DEBUG}
}

proc update_MODELPARAM_VALUE.ACTION_STROBES_WIDTH { MODELPARAM_VALUE.ACTION_STROBES_WIDTH PARAM_VALUE.ACTION_STROBES_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ACTION_STROBES_WIDTH}] ${MODELPARAM_VALUE.ACTION_STROBES_WIDTH}
}

proc update_MODELPARAM_VALUE.HARDWARE_OUTPUT_COUNT { MODELPARAM_VALUE.HARDWARE_OUTPUT_COUNT PARAM_VALUE.HARDWARE_OUTPUT_COUNT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HARDWARE_OUTPUT_COUNT}] ${MODELPARAM_VALUE.HARDWARE_OUTPUT_COUNT}
}

