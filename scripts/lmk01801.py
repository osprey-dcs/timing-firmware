#!/usr/bin/python3

import sys

def fiter(fname):
    with open(fname, 'r') as F:
        for line in F:
            line = line.split('#',1)[0].strip()
            if line:
                yield line

def bmask(low, high):
    assert low<=high, (low, high)
    ml = (1<<low)-1
    mh = (1<<(high+1))-1
    return mh & ~ml

assert bmask(4,7)==0xf0

def analyze(val: int):
    idx = val&0xf
    print(f'# R{idx} 0x{val:08x}')
    for name, defval, _defst, _desc, ridx, blow, bhigh in regmap:
        if ridx!=idx:
            continue
        rval = (val & bmask(blow, bhigh)) >> blow
        print(f'  {name} = {rval}')

def construct(vals: [(str, int)]):
    outs = {0:0, 1:1, 2:2, 3:3, 4:4, 5:5, 15:15}

    for idx, ones in always_bits.items():
        for bit in ones:
            outs[idx] |= 1<<bit

    for iname, ival in vals:
        for name, defval, _defst, _desc, ridx, blow, bhigh in regmap:
            if name!=iname:
                continue

            sval = ival<<blow
            assert (sval & bmask(blow, bhigh)) == sval, (iname, ival) # out of range
            outs[ridx] |= sval
            break

        else:
            print(f'# Warning: No such register: {iname}')


    for rval in outs.values():
        print(f'0x{rval:08X}')

def getargs():
    from argparse import ArgumentParser
    P = ArgumentParser(description='Register value analysis and construction for TI LMK01801 clock divider/buffer')
    P.add_argument('-R', '--reg',
                   action='append',
                   help='Analyze individual register value.  May be repeated')
    P.add_argument('-r', '--reg-file',
                   help='Analyze register values from file, one per line')
    P.add_argument('-c', '--construct',
                   help='Construct register values from file, one "name = value" per line')
    return P

def main():
    A = getargs().parse_args()
    if A.reg is not None:
        for rv in A.reg:
            analyze(int(rv,0))
    elif A.reg_file:
        for line in fiter(A.reg_file):
            analyze(int(line,0))
    elif A.construct:
        rvals = []
        for line in fiter(A.construct):
            name, val = line.split('=',1)
            rvals.append((name.strip(), int(val.strip(),0)))
        construct(rvals)
    else:
        print('No action')
        sys.exit(1)

# undocumented bits which appear as set in Register Map table
always_bits = {
    0: (30, 27, 13, 12),
    3: (28,),
    15: (10, 8, 7, 6, 5),
}

# Extracted from table 9-8, LMK01801 datasheet, rev. d
#
# (name, default val, default state, desc, reg idx, low bit, high bit)
regmap = [
    ("RESET",0,"Not in reset","Performs power on reset for device",0,4,4),
    ("POWERDOWN",0,"Disabled (device is  active)","Device power down control",0,5,5),
    ("CLKout0_3_PD",0,"Disabled","Power down the divider and clock  outputs 0 through 3",0,6,6),
    ("CLKout4_7_PD",0,"Disabled","Power down the divider and clock  outputs 4 through 7",0,7,7),
    ("CLKout8_11_PD",0,"Disabled","Power down the divider and clock  outputs 8 through 11",0,8,8),
    ("CLKout12_13_PD",0,"Disabled","Power down the divider and clock  outputs 12 through 13",0,9,9),
    ("CLKin0_BUF_TYPE",0,"Bipolar","Clock in buffer type",0,10,10),
    ("CLKin1_BUF_TYPE",0,"Bipolar","Clock in buffer type",0,11,11),
    ("CLKin0_DIV",2,"Divide by 2","Divider value for CLKin0",0,14,16),
    ("CLKin0_MUX",0,"Bypass","Enables or bypasses the CLKin0 divider",0,17,18),
    ("CLKin1_DIV",2,"Divide by 2","Divider value for CLKin1",0,19,21),
    ("CLKin1_MUX",0,"Bypass","Enables or bypasses the CLKin1 divider",0,22,23),
    ("CLKout0_TYPE",1,"LVDS","",1,4,6),
    ("CLKout1_TYPE",1,"LVDS","Individual clock output format. Select",1,7,9),
    ("CLKout2_TYPE",1,"LVDS","from LVDS/LVPECL.",1,10,12),
    ("CLKout3_TYPE",1,"LVDS","",1,13,15),
    ("CLKout4_TYPE",1,"LVDS","",1,16,19),
    ("CLKout5_TYPE",1,"LVDS","",1,20,23),
    ("CLKout6_TYPE",1,"LVDS","",1,24,27),
    ("CLKout7_TYPE",1,"LVDS","",1,28,31),
    ("CLKout8_TYPE",1,"LVDS","Individual clock output format. Select",2,4,7),
    ("CLKout9_TYPE",1,"LVDS","from LVDS/LVPECL/LVCMOS.",2,8,11),
    ("CLKout10_TYPE",1,"LVDS","",2,12,15),
    ("CLKout11_TYPE",1,"LVDS","",2,16,19),
    ("CLKout12_TYPE",1,"LVDS","",2,20,23),
    ("CLKout13_TYPE",1,"LVDS","",2,24,27),
    ("CLKout12_13_ADLY",0,"No delay","Analog delay setting for CLKout12 &  CLKout13.",3,4,9),
    ("CLKout12_13_HS",0,"No Shift","Half shift for digital delay.",3,10,10),
    ("SYNC1_QUAL",0,"Not Qualified","Allows SYNC operations to be qualified  by a clock output",3,11,12),
    ("SYNC0_POL_INV",1,"Logic Low","Sets the polarity of the SYNC pin when",3,14,14),
    ("SYNC1_POL_INV",1,"Logic Low","input",3,15,15),
    ("NO_SYNC_CLKout0_3",0,"Will sync","",3,16,16),
    ("NO_SYNC_CLKout4_7",0,"Will sync","Disable individual clock groups from",3,17,17),
    ("NO_SYNC_CLKout8_11",0,"Will sync","being synchronized.",3,18,18),
    ("NO_SYNC_CLKout12_13",0,"Will sync","",3,19,19),
    ("CLKout0_3_OFFSET_PD",1,"Disabled Disabled 5 clock cycles","Enables a fixed 5-cycle digital delay  offset.",3,20,20),
    ("CLKout4_7_OFFSET_PD",1,'','',3,21,21),
    ("CLKout8_11_OFFSET_PD",0,'','',3,22,22),
    ("SYNC0_FAST",0,"Disabled Disabled","Enables synchronization circuitry.",3,23,23),
    ("SYNC1_FAST",0,'','',3,24,24),
    ("SYNC0_AUTO",1,"Automatic","SYNC is started by programming a  Register R5",3,25,25),
    ("SYNC1_AUTO",1,"Automatic","SYNC is started by programming a  Register R4 or R5",3,26,26),
    ("CLKout12_13_DDLY",5,"5 clock cycles","Digital Delay setting for CLKout12 &  CLKout13.",4,4,13),
    ("CLKout0_3_DIV",1,"Divide-by-1","",5,4,6),
    ("CLKout4_7_DIV",1,"Divide-by-1","Divider for clock outputs.",5,7,9),
    ("CLKout8_11_DIV",1,"Divide-by-1","",5,10,12),
    ("CLKout12_ADLY_SEL",0,"No Delay","Enable Digital Delay for CLKout12",5,13,13),
    ("CLKout13_ADLY_SEL",0,"No Delay","Enable Digital Delay for CLKout13",5,14,14),
    ("CLKout12_13_DIV",1,"Divide-by-1","Divider for clock output.",5,17,27),
    ("uWireLock",0,"Writeable","The values of registers R0 to R5 are  lockable",15,4,4),
]

if __name__=='__main__':
    main()
