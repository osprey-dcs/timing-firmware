#
# RF-input installed on Marble FMC1
#

############################# CLOCKS #############################
# FMC1_CLK0_M2C -- FMC1 H4/H5
set_property -dict {PACKAGE_PIN F17 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports FMC1_CLK0_M2C_P]
set_property -dict {PACKAGE_PIN E17 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports FMC1_CLK0_M2C_N]
create_clock -period 8.000 -name FMC1_CLK0_M2C [get_ports FMC1_CLK0_M2C_P]

# FMC1_CLK1_M2C -- FMC1 G2/G3
set_property -dict {PACKAGE_PIN E18 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports FMC1_CLK1_M2C_P]
set_property -dict {PACKAGE_PIN D18 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports FMC1_CLK1_M2C_N]
create_clock -period 8.000 -name FMC1_CLK1_M2C [get_ports FMC1_CLK1_M2C_P]

############################# GPIO #############################
# FMC1 LA00 -- FMC1 G6/G7
#set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[0]}]]
#set_property -dict {PACKAGE_PIN H18 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[0]}]

# FMC1 LA01 -- FMC1 D8/D9
set_property -dict {PACKAGE_PIN G17 IOSTANDARD LVCMOS25} [get_ports {FMC1_LMK01801_LE}]
set_property -dict {PACKAGE_PIN F18 IOSTANDARD LVCMOS25} [get_ports {FMC1_LMK01801_CLK}]

# FMC1 LA02 -- FMC1 H7/H8
#set_property -dict {PACKAGE_PIN K20 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[2]}]
#set_property -dict {PACKAGE_PIN J20 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[2]}]

# FMC1 LA03 -- FMC1 G9/G10
#set_property -dict {PACKAGE_PIN M17 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[3]}]
#set_property -dict {PACKAGE_PIN L18 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[3]}]

# FMC1 LA04 -- FMC1 H10/H11
#set_property -dict {PACKAGE_PIN H19 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[4]}]
#set_property -dict {PACKAGE_PIN G20 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[4]}]

# FMC1 LA05 -- FMC1 D11/D12
set_property -dict {PACKAGE_PIN F19 IOSTANDARD LVCMOS25} [get_ports {FMC1_LMK01801_DATA}]
#set_property -dict {PACKAGE_PIN E20 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[5]}]

# FMC1 LA06 -- FMC1 C10/C11
#set_property -dict {PACKAGE_PIN L19 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[6]}]
#set_property -dict {PACKAGE_PIN L20 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[6]}]

# FMC1 LA07 -- FMC1 H13/H14
#set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[7]}]
#set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[7]}]

# FMC1 LA08 -- FMC1 G12/G13
#set_property -dict {PACKAGE_PIN G19 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[8]}]
#set_property -dict {PACKAGE_PIN F20 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[8]}]

# FMC1 LA09 -- FMC1 D14/D15
#set_property -dict {PACKAGE_PIN J18 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[9]}]
#set_property -dict {PACKAGE_PIN J19 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[9]}]

# FMC1 LA10 -- FMC1 C14/C15
#set_property -dict {PACKAGE_PIN H16 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[10]}]
#set_property -dict {PACKAGE_PIN G16 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[10]}]

# FMC1 LA11 -- FMC1 H16/H17
#set_property -dict {PACKAGE_PIN L17 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[11]}]
#set_property -dict {PACKAGE_PIN K18 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[11]}]

# FMC1 LA12 -- FMC1 G15/G16
#set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[12]}]
#set_property -dict {PACKAGE_PIN F15 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[12]}]

# FMC1 LA13 -- FMC1 D17/D18
#set_property -dict {PACKAGE_PIN D15 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[13]}]
#set_property -dict {PACKAGE_PIN D16 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[13]}]

# FMC1 LA14 -- FMC1 C18/C19
#set_property -dict {PACKAGE_PIN E15 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[14]}]
#set_property -dict {PACKAGE_PIN E16 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[14]}]

# FMC1 LA15 -- FMC1 H19/H20
#set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[15]}]
#set_property -dict {PACKAGE_PIN J16 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[15]}]

# FMC1 LA16 -- FMC1 G18/G19
#set_property -dict {PACKAGE_PIN K16 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[16]}]
#set_property -dict {PACKAGE_PIN K17 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[16]}]

# FMC1 LA17 -- FMC1 D20/D21
#set_property -dict {PACKAGE_PIN E10 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[17]}]
set_property -dict {PACKAGE_PIN D10 IOSTANDARD LVCMOS25} [get_ports {FMC1_ADS7253_DOUTB}]

# FMC1 LA18 -- FMC1 C22/C23
#set_property -dict {PACKAGE_PIN C12 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[18]}]
#set_property -dict {PACKAGE_PIN C11 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[18]}]

# FMC1 LA19 -- FMC1 H22/H23
#set_property -dict {PACKAGE_PIN H14 IOSTANDARD LVCMOS25} [get_ports {FMC1_DI_ENb}]
#set_property -dict {PACKAGE_PIN G14 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[19]}]

# FMC1 LA20 -- FMC1 G21/G22
#set_property -dict {PACKAGE_PIN B15 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[20]}]
#set_property -dict {PACKAGE_PIN A15 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[20]}]

# FMC1 LA21 -- FMC1 H25/H26
#set_property -dict {PACKAGE_PIN D14 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[21]}]
#set_property -dict {PACKAGE_PIN D13 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[21]}]

# FMC1 LA22 -- FMC1 G24/G25
#set_property -dict {PACKAGE_PIN B14 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[22]}]
#set_property -dict {PACKAGE_PIN A14 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[22]}]

# FMC1 LA23 -- FMC1 D23/D24
set_property -dict {PACKAGE_PIN G12 IOSTANDARD LVCMOS25} [get_ports {FMC1_ADS7253_DOUTA}]
set_property -dict {PACKAGE_PIN F12 IOSTANDARD LVCMOS25} [get_ports {FMC1_ADS7253_CLK}]

# FMC1 LA24 -- FMC1 H28/H29
set_property -dict {PACKAGE_PIN A9 IOSTANDARD LVCMOS25} [get_ports {FMC1_DIN[3]}]
set_property -dict {PACKAGE_PIN A8 IOSTANDARD LVCMOS25} [get_ports {FMC1_DIN[4]}]

# FMC1 LA25 -- FMC1 G27/G28
set_property -dict {PACKAGE_PIN G10 IOSTANDARD LVCMOS25} [get_ports {FMC1_DIN[1]}]
set_property -dict {PACKAGE_PIN G9 IOSTANDARD LVCMOS25} [get_ports {FMC1_DIN[2]}]

# FMC1 LA26 -- FMC1 D26/D27
set_property -dict {PACKAGE_PIN E13 IOSTANDARD LVCMOS25} [get_ports {FMC1_ADS7253_CSB}]
set_property -dict {PACKAGE_PIN E12 IOSTANDARD LVCMOS25} [get_ports {FMC1_ADS7253_DIN}]

# FMC1 LA27 -- FMC1 C26/C27
#set_property -dict {PACKAGE_PIN F14 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[27]}]
#set_property -dict {PACKAGE_PIN F13 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[27]}]

# FMC1 LA28 -- FMC1 H31/H32
set_property -dict {PACKAGE_PIN J13 IOSTANDARD LVCMOS25} [get_ports {FMC1_DIN[6]}]
set_property -dict {PACKAGE_PIN H13 IOSTANDARD LVCMOS25} [get_ports {FMC1_DIN[8]}]

# FMC1 LA29 -- FMC1 G30/G31
set_property -dict {PACKAGE_PIN F9 IOSTANDARD LVCMOS25} [get_ports {FMC1_DIN[5]}]
set_property -dict {PACKAGE_PIN F8 IOSTANDARD LVCMOS25} [get_ports {FMC1_DIN[7]}]

# FMC1 LA30 -- FMC1 H34/H35
set_property -dict {PACKAGE_PIN B12 IOSTANDARD LVCMOS25} [get_ports {FMC1_DIN[11]}]
set_property -dict {PACKAGE_PIN B11 IOSTANDARD LVCMOS25} [get_ports {FMC1_DIN[12]}]

# FMC1 LA31 -- FMC1 G33/G34
set_property -dict {PACKAGE_PIN A13 IOSTANDARD LVCMOS25} [get_ports {FMC1_DIN[9]}]
set_property -dict {PACKAGE_PIN A12 IOSTANDARD LVCMOS25} [get_ports {FMC1_DIN[10]}]

# FMC1 LA32 -- FMC1 H37/H38
set_property -dict {PACKAGE_PIN C14 IOSTANDARD LVCMOS25} [get_ports {FMC1_DIN[15]}]
set_property -dict {PACKAGE_PIN C13 IOSTANDARD LVCMOS25} [get_ports FMC1_PPS]

# FMC1 LA33 -- FMC1 G36/G37
set_property -dict {PACKAGE_PIN B10 IOSTANDARD LVCMOS25} [get_ports {FMC1_DIN[13]}]
set_property -dict {PACKAGE_PIN A10 IOSTANDARD LVCMOS25} [get_ports {FMC1_DIN[14]}]


