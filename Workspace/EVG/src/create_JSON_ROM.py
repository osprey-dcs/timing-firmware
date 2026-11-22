# Create JSON file that maps EPICS INP/OUT strings to register numbers

from collections import OrderedDict
import json

import ospreyEVG
import ospreyEVR

#############################################################################
# Marble support

def base_build():
    R = {
        "__metadata__": {
          "si570Ref": 270, # MHz for 570NBB001808DGR on Marble 1.4.x
        },
        "FPGA:powerUp_": {
          "access": "rw",
          "addr_width": 0,
          "base_addr": 10,
          "data_width": 1,
          "sign": "unsigned"
        },
        "FPGA:loops": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 11,
          "data_width": 32,
          "sign": "unsigned"
        },
        "firmwareBuildDate": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 20,
          "data_width": 32,
          "sign": "unsigned"
        },
        "softwareBuildDate": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 21,
          "data_width": 32,
          "sign": "unsigned"
        },
        "FPGA:reboot": {
          "access": "w",
          "addr_width": 0,
          "base_addr": 30,
          "data_width": 32,
          "sign": "unsigned"
        },
        "FPGA:uptime": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 40,
          "data_width": 32,
          "sign": "unsigned"
        },
        "FPGA:MODE:EVG": {
          "access": "rw",
          "addr_width": 0,
          "base_addr": 60,
          "data_width": 1,
          "sign": "unsigned"
        },
        "FMC:1:serialNumber": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 50,
          "data_width": 32,
          "sign": "unsigned"
        },
        "FMC:2:serialNumber": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 51,
          "data_width": 32,
          "sign": "unsigned"
        },
        "FMC:1:partNumber": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 54,
          "data_width": 32,
          "sign": "unsigned"
        },
        "FMC:2:partNumber": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 55,
          "data_width": 32,
          "sign": "unsigned"
        },
        "MGT:reset": {
          "access": "w",
          "addr_width": 0,
          "base_addr": 56,
          "data_width": 1,
          "sign": "unsigned"
        },
        "MARBLE:mgtRefClk0": {
          "access": "rw",
          "addr_width": 0,
          "base_addr": 80,
          "data_width": 32,
          "sign": "unsigned"
        },
        "FPGA:Temperature": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 100,
          "data_width": 16,
          "sign": "unsigned"
        },
        "FPGA:VccINT": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 101,
          "data_width": 16,
          "sign": "unsigned"
        },
        "FPGA:VccAUX": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 102,
          "data_width": 16,
          "sign": "unsigned"
        },
        "FPGA:VBRAM": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 103,
          "data_width": 16,
          "sign": "unsigned"
        },
        "MARBLE:U29:Temp": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 132,
          "data_width": 16,
          "sign": "unsigned"
        },
        "MARBLE:U28:Temp": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 133,
          "data_width": 16,
          "sign": "unsigned"
        },
        # see iicFPGAfetchSysmon()
        "MARBLE:FMC1:P12I": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+0,
          "data_width": 16,
          "sign": "signed"
        },
        "MARBLE:FMC1:P12V": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+1,
          "data_width": 16,
          "sign": "unsigned"
        },
        "MARBLE:FMC2:P12I": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+2,
          "data_width": 16,
          "sign": "signed"
        },
        "MARBLE:FMC2:P12V": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+3,
          "data_width": 16,
          "sign": "unsigned"
        },
        "MARBLE:P12I": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+4,
          "data_width": 16,
          "sign": "signed"
        },
        "MARBLE:P12V": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+5,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP1:nomRate": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+6,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP1:Temperature": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+7,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP1:Vcc": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+8,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP1:RxPower1": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+9,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP1:RxPower2": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+10,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP1:RxPower3": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+11,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP1:RxPower4": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+12,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP1:TxPower1": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+13,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP1:TxPower2": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+14,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP1:TxPower3": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+15,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP1:TxPower4": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+16,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP1:nomRate": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+17,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP2:Temperature": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+18,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP2:Vcc": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+19,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP2:RxPower1": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+20,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP2:RxPower2": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+21,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP2:RxPower3": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+22,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP2:RxPower4": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+23,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP2:TxPower1": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+24,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP2:TxPower2": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+25,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP2:TxPower3": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+26,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP2:TxPower4": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 356+27,
          "data_width": 16,
          "sign": "unsigned"
        },
        "MARBLE:EVG:status": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 260,
          "data_width": 32,
          "sign": "unsigned"
        },
        "MARBLE:VCXO:SR": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 292,
          "data_width": 32,
          "sign": "unsigned"
        },
        "MARBLE:VCXO:ASR": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 293,
          "data_width": 32,
          "sign": "unsigned"
        },
        "MARBLE:VCXO:PPS": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 294,
          "data_width": 32,
          "sign": "unsigned"
        },
        "MGT:status": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 324,
          "data_width": 32,
          "sign": "unsigned"
        },
        "MGT:clkStatus": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 325,
          "data_width": 32,
          "sign": "unsigned"
        },
        "MARBLE:PLL:SET_Y1": {
          "access": "w",
          "addr_width": 0,
          "base_addr": 86,
          "data_width": 16,
          "sign": "signed"
        },
        "MARBLE:PLL:SET_Y3": {
          "access": "w",
          "addr_width": 0,
          "base_addr": 87,
          "data_width": 16,
          "sign": "signed"
        },
        "MARBLE:PPS:LOCAL:CSR": {
          "access": "rw",
          "addr_width": 0,
          "base_addr": 88,
          "data_width": 32,
          "sign": "unsigned"
        },
        "MARBLE:RFIN:inputs": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 70,
          "data_width": 16,
          "sign": "unsigned"
        },
        "MARBLE:RFIN:level1": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 71,
          "data_width": 16,
          "sign": "unsigned"
        },
        "MARBLE:RFIN:level2": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 72,
          "data_width": 16,
          "sign": "unsigned"
        },
        "MARBLE:PMOD:inputs": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 75,
          "data_width": 8,
          "sign": "unsigned"
        },
        "FPGA:IO:select": {
            "access": "r",
            "addr_width": 0,
            "base_addr": 89,
            "data_width": 32,
            "sign": "unsigned"
        },
        "MARBLE:SI570:SET": {
            "access": "rw",
            "addr_width": 1,
            "base_addr": 90,
            "data_width": 24,
            "sign": "unsigned"
        },
        "MARBLE:SI570:CAL": {
            "access": "r",
            "addr_width": 1,
            "base_addr": 92,
            "data_width": 24,
            "sign": "unsigned"
        },
        "TRGOUT:ident": {
            "access": "r",
            "addr_width": 2, # 4
            "base_addr": 400,
            "data_width": 24,
            "sign": "unsigned"
        },
        "TRGOUT:sts": {
            "access": "r",
            "addr_width": 1, # 2
            "base_addr": 404,
            "data_width": 24,
            "sign": "unsigned"
        },
        "CLKIN:div1": {
            "access": "rw",
            "addr_width": 0,
            "base_addr": 500,
            "data_width": 7, # [1, 64]
            "sign": "unsigned"
        },
        "CLKIN:div2": {
            "access": "rw",
            "addr_width": 0,
            "base_addr": 501,
            "data_width": 7, # [1, 64]
            "sign": "unsigned"
        },
    }
    return R

def mpsLocal_build(MPS_REG_BASE=10000, mpsOutputCount=2):
    R = {
        "MPS:invert": {
            "access": "rw",
            "addr_width": 0,
            "base_addr": MPS_REG_BASE + 0,
            "data_width": 32,
            "sign": "unsigned",
        },
        "MPS:forceTrip": {
            "access": "rw",
            "addr_width": 0,
            "base_addr": MPS_REG_BASE + 1,
            "data_width": 32,
            "sign": "unsigned",
        },
        "MPS:required": {
            "access": "rw",
            "addr_width": 0,
            "base_addr": MPS_REG_BASE + 2,
            "data_width": 32,
            "sign": "unsigned",
        },
        "MPS:tripped": {
            "access": "r",
            "addr_width": 0,
            "base_addr": MPS_REG_BASE + 3,
            "data_width": 32,
            "sign": "unsigned",
        },
    }

    for addr, idx in enumerate(range(1, mpsOutputCount+1), MPS_REG_BASE+100):
        R[f"MPS:status:{idx}"] = {
            "access": "r",
            "addr_width": 0,
            "base_addr": addr,
            "data_width": 8,
            "sign": "unsigned",
        }

    for addr, idx in enumerate(range(1, mpsOutputCount+1), MPS_REG_BASE+200):
        R[f"MPS:check:{idx}"] = {
            "access": "rw",
            "addr_width": 0,
            "base_addr": addr,
            "data_width": 8,
            "sign": "unsigned",
        }

    for addr, idx in enumerate(range(1, mpsOutputCount+1), MPS_REG_BASE+300):
        R[f"MPS:goodState:{idx}"] = {
            "access": "rw",
            "addr_width": 0,
            "base_addr": addr,
            "data_width": 8,
            "sign": "unsigned",
        }

    for addr, idx in enumerate(range(1, mpsOutputCount+1), MPS_REG_BASE+400):
        R[f"MPS:firstFault:{idx}"] = {
            "access": "r",
            "addr_width": 0,
            "base_addr": addr,
            "data_width": 8,
            "sign": "unsigned",
        }

    for addr, idx in enumerate(range(1, mpsOutputCount+1), MPS_REG_BASE+500):
        R[f"MPS:faultSeconds:{idx}"] = {
            "access": "r",
            "addr_width": 0,
            "base_addr": addr,
            "data_width": 8,
            "sign": "unsigned",
        }

    for addr, idx in enumerate(range(1, mpsOutputCount+1), MPS_REG_BASE+600):
        R[f"MPS:faultTicks:{idx}"] = {
            "access": "r",
            "addr_width": 0,
            "base_addr": addr,
            "data_width": 8,
            "sign": "unsigned",
        }

    return R

def merge_core(base, core):
    'Merge register map and metadata map'
    Mb = base.get('__metadata__') or {}
    Mc = core.get('__metadata__') or {}
    Mb.update(Mc)
    base.update(core)
    base['__metadata__'] = Mb

def evt_merge():
    R = base_build()
    merge_core(R, mpsLocal_build(
        MPS_REG_BASE=100000,
        mpsOutputCount=8,
    ))
    merge_core(R, ospreyEVG.ospreyEVG_build(
        EVG_REG_BASE=1000000,
        timerCount=8,
        hwTriggerCount=16,
        seqBankCount=8,
        seqAddrWidth=11,
    ))
    merge_core(R, ospreyEVR.ospreyEVR_build(
        EVR_REG_BASE=1100000,
        hwOutputCount=24,
    ))
    return R

def sortOrdered(D: dict) -> OrderedDict:
  L = list(D.items())
  L.sort()
  return OrderedDict(L)

def main():
    R = evt_merge()
    S = json.dumps(R)
    # stablize order of dict (top, and nested)
    R2 = json.loads(S, object_hook=sortOrdered)
    S2 = json.dumps(R2, indent=2) # remove indent to save a few bytes
    print(S2)

if __name__=='__main__':
    main()
