# Target constraints file -- Extra constraints (Chipscope, etc.)




set_false_path -from [get_clocks fiberLinks_i/mgtWrapper_i/mgt_i/inst/mgt_i/gt0_mgt_i/gtxe2_i/RXOUTCLK] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks fiberLinks_i/mgtWrapper_i/mgt_i/inst/mgt_i/gt0_mgt_i/gtxe2_i/TXOUTCLK] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks fiberLinks_i/mgtWrapper_i/mgt_i/inst/mgt_i/gt1_mgt_i/gtxe2_i/RXOUTCLK] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks fiberLinks_i/mgtWrapper_i/mgt_i/inst/mgt_i/gt5_mgt_i/gtxe2_i/RXOUTCLK] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0]]
