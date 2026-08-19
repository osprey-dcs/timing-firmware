#
# Trigger Output FMC installed on Marble FMC2
#

########################### Marble FMC2 ##########################
############################# CLOCKS #############################

# FMC2_GBTCLK0_M2C -- FMC2 D4/D5
# FMC2_GBTCLK1_M2C -- FMC2 B20/B21
# Cleaned Clock signals are routed through crosspoint switch U2 on Marble
# This then can then go to MGT_CLK_0/1/2/3 on Marble
# FPGA pins for these signals are as follows:
# MGT_CLK_0 - D6/D5
# MGT_CLK_1 - F6/F5
# MGT_CLK_2 - H6/H5
# MGT_CLK_3 - K6/K5

# FMC2 LA00 CC -- FMC2 G6/G7
set_property -dict {PACKAGE_PIN Y22  IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports FMC2_Cleaned_CLK_P[0]]
set_property -dict {PACKAGE_PIN AA22 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports FMC2_Cleaned_CLK_N[0]]
create_clock -period 8.000 -name FMC2_Cleaned_CLK0 [get_ports FMC2_Cleaned_CLK_P[0]]

# FMC2 LA01 CC -- FMC2 D8/D9
set_property -dict {PACKAGE_PIN AA23 IOSTANDARD LVDS_25} [get_ports FMC2_Recovered_CLK_N[0]]
set_property -dict {PACKAGE_PIN AB24 IOSTANDARD LVDS_25} [get_ports FMC2_Recovered_CLK_P[0]]

# FMC2 LA17 CC -- FMC2 D20/D21
set_property -dict {PACKAGE_PIN G22 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports FMC2_Cleaned_CLK_P[1]]
set_property -dict {PACKAGE_PIN F23 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports FMC2_Cleaned_CLK_N[1]]
create_clock -period 8.000 -name FMC2_Cleaned_CLK1 [get_ports FMC2_Cleaned_CLK_P[1]]

# FMC2 LA18 CC -- FMC2 C22/C23
set_property -dict {PACKAGE_PIN G24 IOSTANDARD LVDS_25} [get_ports FMC2_Recovered_CLK_N[1]]
set_property -dict {PACKAGE_PIN F24 IOSTANDARD LVDS_25} [get_ports FMC2_Recovered_CLK_P[1]]

# FMC2_CLK0_M2C -- FMC2 H4/H5 -- Unused
#set_property -dict {PACKAGE_PIN F17 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports FMC2_CLK0_M2C_P]
#set_property -dict {PACKAGE_PIN E17 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports FMC2_CLK0_M2C_N]
#create_clock -period 8.000 -name FMC2_CLK0_M2C [get_ports FMC2_CLK0_M2C_P]

# FMC2_CLK1_M2C -- FMC2 G2/G3 -- Unused
#set_property -dict {PACKAGE_PIN E18 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports FMC2_CLK1_M2C_P]
#set_property -dict {PACKAGE_PIN D18 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports FMC2_CLK1_M2C_N]
#create_clock -period 8.000 -name FMC2_CLK1_M2C [get_ports FMC2_CLK1_M2C_P]

############################## Marble FMC2 ##############################
############################ Digital Outputs ############################

# FMC2 LA08 -- FMC2 G12/G13
set_property -dict {PACKAGE_PIN AC23 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_P[0]]
set_property -dict {PACKAGE_PIN AC24 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_N[0]]

# FMC2 LA07 -- FMC2 H13/H14
set_property -dict {PACKAGE_PIN AB22 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_P[1]]
set_property -dict {PACKAGE_PIN AC22 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_N[1]]

# FMC2 LA12 -- FMC2 G15/G16
set_property -dict {PACKAGE_PIN AA25 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_P[2]]
set_property -dict {PACKAGE_PIN AB25 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_N[2]]

# FMC2 LA09 -- FMC2 D14/D15
set_property -dict {PACKAGE_PIN U26 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_P[3]]
set_property -dict {PACKAGE_PIN V26 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_N[3]]

# FMC2 LA10 -- FMC2 C14/C15
set_property -dict {PACKAGE_PIN AE23 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_P[4]]
set_property -dict {PACKAGE_PIN AF23 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_N[4]]

# FMC2 LA16 -- FMC2 G18/G19
set_property -dict {PACKAGE_PIN W25 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_P[5]]
set_property -dict {PACKAGE_PIN W26 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_N[5]]

# FMC2 LA13 -- FMC2 D17/D18
set_property -dict {PACKAGE_PIN V23 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_P[6]]
set_property -dict {PACKAGE_PIN V24 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_N[6]]

# FMC2 LA14 -- FMC2 C18/C19
set_property -dict {PACKAGE_PIN U24 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_P[7]]
set_property -dict {PACKAGE_PIN U25 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_N[7]]

# FMC2 LA20 -- FMC2 G21/G22
set_property -dict {PACKAGE_PIN L22 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_P[8]]
set_property -dict {PACKAGE_PIN K22 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_N[8]]

# FMC2 LA25 -- FMC2 G27/G28
set_property -dict {PACKAGE_PIN D23 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_P[9]]
set_property -dict {PACKAGE_PIN D24 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_N[9]]

# FMC2 LA29 -- FMC2 G30/G31
set_property -dict {PACKAGE_PIN J26 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_P[10]]
set_property -dict {PACKAGE_PIN H26 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_N[10]]

# FMC2 LA28 -- FMC2 H31/H32
set_property -dict {PACKAGE_PIN G25 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_P[11]]
set_property -dict {PACKAGE_PIN G26 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_N[11]]

# FMC2 LA31 -- FMC2 G33/G34
set_property -dict {PACKAGE_PIN E21 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_P[12]]
set_property -dict {PACKAGE_PIN E22 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_N[12]]

# FMC2 LA30 -- FMC2 H34/H35
set_property -dict {PACKAGE_PIN D26 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_P[13]]
set_property -dict {PACKAGE_PIN C26 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_N[13]]

# FMC2 LA32 -- FMC2 H37/H38
set_property -dict {PACKAGE_PIN B20 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_P[14]]
set_property -dict {PACKAGE_PIN A20 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_N[14]]

# FMC2 LA33 -- FMC2 G36/G37
set_property -dict {PACKAGE_PIN C21 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_P[15]]
set_property -dict {PACKAGE_PIN B21 IOSTANDARD LVDS_25} [get_ports FMC2_D_Output_N[15]]

############################## Marble FMC2 ##############################
################################## SPI ##################################
#### Cleaner 0 ####
# FMC2 LA06 -- FMC2 C10/C11
set_property -dict {PACKAGE_PIN AD23 IOSTANDARD LVCMOS25 PULLDOWN true} [get_ports FMC2_Cleaner_SPI_CLK[0]]
set_property -dict {PACKAGE_PIN AD24 IOSTANDARD LVCMOS25 PULLDOWN true} [get_ports FMC2_Cleaner_SPI_SDI[0]]

# FMC2 LA04 -- FMC2 H11
set_property -dict {PACKAGE_PIN W21 IOSTANDARD LVCMOS25 PULLUP true} [get_ports FMC2_Cleaner_SPI_SDO[0]]

# FMC2 LA03 -- FMC2 G10
set_property -dict {PACKAGE_PIN AE26 IOSTANDARD LVCMOS25 PULLUP true} [get_ports FMC2_Cleaner_SPI_CSn[0]]

#### Cleaner 1 ####
# FMC2 LA23 -- FMC2 D24
set_property -dict {PACKAGE_PIN H24 IOSTANDARD LVCMOS25 PULLDOWN true} [get_ports FMC2_Cleaner_SPI_CLK[1]]

# FMC2 LA26 -- FMC2 D26
set_property -dict {PACKAGE_PIN F25 IOSTANDARD LVCMOS25 PULLDOWN true} [get_ports FMC2_Cleaner_SPI_SDI[1]]

# FMC2 LA24 -- FMC2 H29
set_property -dict {PACKAGE_PIN J25 IOSTANDARD LVCMOS25 PULLUP true} [get_ports FMC2_Cleaner_SPI_SDO[1]]

# FMC2 LA22 -- FMC2 G25
set_property -dict {PACKAGE_PIN D25 IOSTANDARD LVCMOS25 PULLUP true} [get_ports FMC2_Cleaner_SPI_CSn[1]]

############################## Marble FMC2 ##############################
################################# GPIO ##################################

# FMC2 LA00 CC -- FMC2 G6/G7 -- Used as CLOCK

# FMC2 LA01 CC -- FMC2 D8/D9 -- Used as CLOCK

# FMC2 LA02 -- FMC2 H7/H8
set_property -dict {PACKAGE_PIN AE22 IOSTANDARD LVCMOS25} [get_ports FMC2_Cleaner_Fault_INTR[0]]
set_property -dict {PACKAGE_PIN AF22 IOSTANDARD LVCMOS25} [get_ports FMC2_Cleaner_Fault_LOS_XO[0]]

# FMC2 LA03 -- FMC2 G9 -- G10 Defined in SPI Section
set_property -dict {PACKAGE_PIN AD26 IOSTANDARD LVCMOS25} [get_ports FMC2_Cleaner_RSTn[0]]

# FMC2 LA04 -- FMC2 H10 -- H11 Defined in SPI Section
set_property -dict {PACKAGE_PIN V21 IOSTANDARD LVCMOS25} [get_ports FMC2_Cleaner_Fault_LOL[0]]

# FMC2 LA05 -- FMC2 D11/D12
#set_property -dict {PACKAGE_PIN AB26 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_P[5]}]
set_property -dict {PACKAGE_PIN AC26 IOSTANDARD LVCMOS25} [get_ports FMC2_Cleaner_ClkBuffer_OEn[0]]

# FMC2 LA06 -- FMC2 C10/C11 -- Defined in SPI Section

# FMC2 LA07 -- FMC2 H13/H14 -- Defined in Digital Outputs Section

# FMC2 LA08 -- FMC2 G12/G13 -- Defined in Digital Outputs Section

# FMC2 LA09 -- FMC2 D14/D15 -- Defined in Digital Outputs Section

# FMC2 LA10 -- FMC2 C14/C15 -- Defined in Digital Outputs Section

# FMC2 LA11 -- FMC2 H16/H17
#set_property -dict {PACKAGE_PIN W23 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_P[11]}]
#set_property -dict {PACKAGE_PIN W24 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_N[11]}]

# FMC2 LA12 -- FMC2 G15/G16 -- Defined in Digital Outputs Section

# FMC2 LA13 -- FMC2 D17/D18 -- Defined in Digital Outputs Section

# FMC2 LA14 -- FMC2 C18/C19 -- Defined in Digital Outputs Section

# FMC2 LA15 -- FMC2 H19/H20
set_property -dict {PACKAGE_PIN U22 IOSTANDARD LVCMOS25 PULLDOWN true} [get_ports FMC2_OE_Digital_Outputs]
#set_property -dict {PACKAGE_PIN V22 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_N[15]}]

# FMC2 LA16 -- FMC2 G18/G19 -- Defined in Digital Outputs Section

# FMC2 LA17 CC -- FMC2 D20/D21 -- Used as CLOCK

# FMC2 LA18 CC -- FMC2 C22/C23 -- Used as CLOCK

# FMC2 LA19 -- FMC2 H22/H23
set_property -dict {PACKAGE_PIN K23 IOSTANDARD LVCMOS25} [get_ports FMC2_Cleaner_LevelShift_OEn[1]]
#set_property -dict {PACKAGE_PIN J23 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_N[19]}]

# FMC2 LA20 -- FMC2 G21/G22 -- Defined in Digital Outputs Section

# FMC2 LA21 -- FMC2 H25/H26
set_property -dict {PACKAGE_PIN J21 IOSTANDARD LVCMOS25} [get_ports FMC2_Cleaner_Fault_INTR[1]]
set_property -dict {PACKAGE_PIN H22 IOSTANDARD LVCMOS25} [get_ports FMC2_Cleaner_Fault_LOS_XO[1]]

# FMC2 LA22 -- FMC2 G24 -- G25 Defined in SPI Section
set_property -dict {PACKAGE_PIN E25 IOSTANDARD LVCMOS25} [get_ports FMC2_Cleaner_RSTn[1]]

# FMC2 LA23 -- FMC2 D23 -- D24 Defined in SPI Section
#set_property -dict {PACKAGE_PIN H23 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_P[23]}]

# FMC2 LA24 -- FMC2 H28 -- H29 Defined in SPI Section
set_property -dict {PACKAGE_PIN J24 IOSTANDARD LVCMOS25} [get_ports FMC2_Cleaner_Fault_LOL[1]]

# FMC2 LA25 -- FMC2 G27/G28 -- Defined in Digital Outputs Section

# FMC2 LA26 -- FMC2 D27 -- D26 Defined in SPI Section
set_property -dict {PACKAGE_PIN E26 IOSTANDARD LVCMOS25} [get_ports FMC2_Cleaner_ClkBuffer_OEn[1]]

# FMC2 LA27 -- FMC2 C26/C27
set_property -dict {PACKAGE_PIN H21 IOSTANDARD LVCMOS25} [get_ports FMC2_Cleaner_LevelShift_OEn[0]]
set_property -dict {PACKAGE_PIN G21 IOSTANDARD LVCMOS25 PULLDOWN true} [get_ports FMC2_Heartbeat_LED]

# FMC2 LA28 -- FMC2 H31/H32 -- Defined in Digital Outputs Section

# FMC2 LA29 -- FMC2 G30/G31 -- Defined in Digital Outputs Section

# FMC2 LA30 -- FMC2 H34/H35 -- Defined in Digital Outputs Section

# FMC2 LA31 -- FMC2 G33/G34 -- Defined in Digital Outputs Section

# FMC2 LA32 -- FMC2 H37/H38 -- Defined in Digital Outputs Section

# FMC2 LA33 -- FMC2 G36/G37 -- Defined in Digital Outputs Section



