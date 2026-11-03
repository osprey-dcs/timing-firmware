#!/usr/bin/env python3

# register analysis for Si5394 jitter cleaner.
# Takes a CSV or C code with a list of tuples of 16-bit register address and 8 bit value.
#  python si5394reg.py ../Workspace/EVG/src/si5394Registers.h

# The OEM does not bother to document the function of soooo many registers!
# Their CBPro software sets non-zero values to RESERVED and undocumented addresses!!

import re
from pathlib import Path
from dataclasses import dataclass

@dataclass
class RegField:
    addr: int
    arange: (int, int)
    name: str
    nrange: (int, int)
    access: str

def bmask(L, H):
    assert L<=H, (L, H)
    return ((1<<(H-L+1))-1)<<L

def bextract(val, L, H):
    assert L<=H, (L, H)
    val = val>>L
    val &= (1<<(H-L+1))-1
    return val

def load_reg_fields() -> [RegField]:
    'Read list of register fields (zero or more per address'
    addrs = set()
    R = []

    for lno, line in enumerate(Path(__file__).with_name('si5394reg.csv').read_text().splitlines(), 1):
        try:
            line = line.strip()
            if line[0:1] in ('','#'):
                continue
            addr, mask, access, name = line.split(',')
            addr = int(addr.strip('"'), 0)
            mask = mask.strip('"').split(':')
            access = access.strip('"')
            name = name.strip('"')

            if len(mask)==2:
                H, L = mask
            elif len(mask)==1:
                H = L = mask[0]
            else:
                assert False, mask
            H, L = int(H), int(L)

            for oR in R:
                if oR.addr!=addr:
                    continue
                # flag overlapping registers (copypasta in family guide tables!)
                assert bmask(L,H) & bmask(*oR.arange) == 0

            assert addr not in addrs, addr

            R.append(RegField(
                addr=addr,
                arange=(L%8, H%8),
                name=name,
                nrange=(L, H),
                access=access,
            ))
        except Exception:
            raise RuntimeError(f'line {lno}: {line!r}')
    return R

def load_reg_defaults() -> {int:int}:
    'Load default values by address'

    ret = {}
    for lno, line in enumerate(Path(__file__).with_name('si5394def.csv').read_text().splitlines(), 1):
        try:
            line = line.strip()
            if line[0:1] in ('','#'):
                continue
            addr, value = line.split(',')
            addr = int(addr.strip().strip('"'), 0)
            value = int(value.strip().strip('"'), 0)
            assert addr not in ret
            ret[addr] = value
        except Exception:
            raise RuntimeError(f'line {lno}: {line!r}')
    return ret

def getargs():
    from argparse import ArgumentParser, FileType
    P = ArgumentParser()
    P.add_argument('regaddr', type=FileType('r'))
    return P

def main(args):
    Rs = load_reg_fields();
    Ds = load_reg_defaults()

    for line in args.regaddr:
        line = line.rstrip()

        inp = line.replace('{','').replace('}','').replace(',','').strip()
        inp = re.split('\s+', inp)
        try:
            addr, val = int(inp[0], 0), int(inp[1], 0)
        except (IndexError, ValueError) as e:
            print(line)
            continue

        print(line, end='')
        found = False
        remainder = val
        totalmask = 0
        for R in Rs:
            if addr != R.addr:
                continue
            if not found:
                print(' //', end='')
            found = True

            print(f' {R.name}[{R.nrange[1]}:{R.nrange[0]}]={bextract(val, *R.arange)}', end='')
            totalmask |= bmask(*R.arange)
            remainder = remainder & ~bmask(*R.arange)

        if not found:
            print(' // !!' if val else ' // ??')
        else:
            defval = Ds.get(addr, 0)
            if remainder & ~totalmask != defval & ~totalmask:
                print(f' !!=0x{remainder:x}', end='')
            print('') # EoL

if __name__=='__main__':
    main(getargs().parse_args())
