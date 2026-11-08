#!/usr/bin/env python3

"""
Digest a Design Report text file produced by CBPro for an Si539x jitter cleaner
Emit a C array fragment expanding of a sequence of macros for each device
address.

  #define SI539x_SEQ_PAGE(PAGE) ...
  #define SI539x_SEQ_REG(ADDR, MASK, VALUE)
  #define SI539x_SEQ_DELAY(MS)
  struct Si539xSetup {
    ...
  } Si539xRegs = {
  #include "Design-Report.h"
  };
"""

from collections import OrderedDict
import re

# 0x0006[23:0]  TOOL_VERSION                0                  0x000000
#    1    2 3        4                                             5
_line = re.compile(r'''
    \s*
    (0x[0-9A-Fa-f]+)
    \s*
    \[ (\d+) (?: : (\d+) )? \]
    \s*
    (\S+)
    \s*
    \d+
    \s*
    (0x[0-9A-Fa-f]+)
    \s*
''', re.VERBOSE)

def bmask(L, H):
    assert L<=H, (L, H)
    return ((1<<(H-L+1))-1)<<L

def bextract(val, L, H):
    assert L<=H, (L, H)
    val = val>>L
    val &= (1<<(H-L+1))-1
    return val

def getargs():
    from argparse import ArgumentParser, FileType
    P = ArgumentParser()
    P.add_argument('input', type=FileType('r'),
                   help='CBPro Design Report text file')
    P.add_argument('output', type=FileType('w'),
                   help='Output array fragment')
    P.add_argument('-v','--verbose', action='store_true',
                   help='Print non-matching input lines')
    return P

def main(args):
    amap = OrderedDict()

    for line in args.input:
        line = line.strip()
        if line[:1] in ('', '#'):
            continue

        M = _line.match(line)
        if M is None:
            if args.verbose:
                print(line)
            continue

        addr, high, low, rname, value = M.groups()
        if low is None:
            low = high

        addr, high, low, value = int(addr,0), int(high), int(low), int(value, 0)
        assert low <= 7, (addr, high, low, rname)

        mask = bmask(low, high)
        value <<= low

        assert value & mask == value, (value, mask, rname)

        while mask:
            if addr not in amap:
                amap[addr] = []

            # group by address
            amap[addr].append((mask & 0xff, value & 0xff, rname))

            addr += 1
            mask >>= 8
            value >>= 8

    args.output.write('  //SI539x_SEQ_REG( ADDR, MASK, VALUE )\n')
    args.output.write('''\
#ifndef SI539x_SEQ_PAGE
#  error Forgot to define SI539x_SEQ_PAGE
#  define SI539x_SEQ_PAGE( PAGE )
#endif
#ifndef SI539x_SEQ_REG
#  error Forgot to define SI539x_SEQ_REG
#  define SI539x_SEQ_REG( ADDR, MASK, VALUE )
#endif
#ifndef SI539x_SEQ_DELAY
#  error Forgot to define SI539x_SEQ_DELAY
#  define SI539x_SEQ_DELAY( MS )
#endif
''')

    current_page = -1
    def select_page(page: int):
        nonlocal current_page
        if current_page != page:
            args.output.write(f'    SI539x_SEQ_PAGE( 0x{page:x} ),\n')
            current_page = page

    def outreg(addr:int, mask:int, value:int):
        assert mask&0xff==mask
        assert value&0xff==value
        args.output.write(f'    SI539x_SEQ_REG( 0x{addr:04x}, 0x{mask:02x}, 0x{value:02x} ),\n')

    # Si539x family guide section 4.2 Dynamic PLL Changes
    args.output.write('  // Preamble\n')
    select_page(0xB)
    #  "RERSERVED" registers, because spelling is hard!
    outreg(0xb24, 0xff, 0xc0)
    outreg(0xb25, 0xff, 0x00)
    select_page(0x5)
    outreg(0x540, 0xff, 0x01)
    # delay 300 ms except for grade P/E then 625 ms
    # so take the worst case
    args.output.write('    SI539x_SEQ_DELAY(625),\n')
    args.output.write('  // Update configuration\n')

    for addr, Fs in amap.items():
        select_page((addr>>8)&0xff)
        M, V = 0, 0
        for mask, value, rname in Fs:
            M |= mask
            V |= value
            args.output.write(f'    //                      0x{mask:02x}  0x{value:02x} - {rname}\n')

        outreg(addr, M, V)

    # tricky... BW_UPDATE_PLL is not mentioned in section 4.2
    # but is emitted in the post-amble section by CBPro.
    args.output.write('  // BW_UPDATE_PLL\n')
    select_page(0x5)
    outreg(0x514, 0xff, 0x01)
    args.output.write('  // Soft-reset\n')
    select_page(0x0)
    outreg(0x01c, 0xff, 0x01)
    args.output.write('  // Postamble\n')
    select_page(0x5)
    outreg(0x540, 0xff, 0x00)
    select_page(0xB)
    outreg(0xb24, 0xff, 0xc3)
    outreg(0xb25, 0xff, 0x02)


if __name__=='__main__':
    main(getargs().parse_args())
