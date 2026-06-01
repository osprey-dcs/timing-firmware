# Create JSON file that maps EPICS INP/OUT strings to register numbers

from collections import OrderedDict
import json

import ospreyEVG
import ospreyEVR

#############################################################################
# Marble support

def base_build():
    R = {
        "FPGA:powerUp_": {
          "access": "rw",
          "addr_width": 0,
          "base_addr": 10,
          "data_width": 1,
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
        "MARBLE:FMC1:P12I": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 164,
          "data_width": 16,
          "sign": "signed"
        },
        "MARBLE:FMC1:P12V": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 165,
          "data_width": 16,
          "sign": "unsigned"
        },
        "MARBLE:FMC2:P12I": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 166,
          "data_width": 16,
          "sign": "signed"
        },
        "MARBLE:FMC2:P12V": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 167,
          "data_width": 16,
          "sign": "unsigned"
        },
        "MARBLE:P12I": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 168,
          "data_width": 16,
          "sign": "signed"
        },
        "MARBLE:P12V": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 169,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP1:Temperature": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 170,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP1:Vcc": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 171,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP1:RxPower1": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 172,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP1:RxPower2": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 173,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP1:RxPower3": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 174,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP1:RxPower4": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 175,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP2:Temperature": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 176,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP2:Vcc": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 177,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP2:RxPower1": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 178,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP2:RxPower2": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 179,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP2:RxPower3": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 180,
          "data_width": 16,
          "sign": "unsigned"
        },
        "QSFP2:RxPower4": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 181,
          "data_width": 16,
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
        "Marble:RFIN:inputs": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 70,
          "data_width": 16,
          "sign": "unsigned"
        },
        "Marble:RFIN:level1": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 71,
          "data_width": 16,
          "sign": "unsigned"
        },
        "Marble:RFIN:level2": {
          "access": "r",
          "addr_width": 0,
          "base_addr": 72,
          "data_width": 16,
          "sign": "unsigned"
        },
        "Marble:PMOD:inputs": {
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
        }
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

#    for addr, tmr in enumerate(range(1, timerCount+1), EVG_REG_BASE+120):
#        R[f"EVG:TMR:{tmr}:divisor"] = {
#            "access": "w",
#            "addr_width": 0,
#            "base_addr": addr,
#            "data_width": 32,
#            "sign": "unsigned",
#        }
#
#    for off, trg in enumerate(range(1, hwTriggerCount+1)):
#        R[f"EVG:TRG:r{trg}:ev"] = {
#            "access": "w",
#            "addr_width": 0,
#            "base_addr": EVG_REG_BASE+140+2*off+0,
#            "data_width": 8,
#            "sign": "unsigned",
#        }
#        R[f"EVG:TRG:f{trg}:ev"] = {
#            "access": "w",
#            "addr_width": 0,
#            "base_addr": EVG_REG_BASE+140+2*off+1,
#            "data_width": 8,
#            "sign": "unsigned",
#        }
#
#    for off, seq in enumerate(range(1, seqBankCount+1)):
#        R[f"EVG:SEQ:{seq}:hw:r"] = {
#            "access": "w",
#            "addr_width": 0,
#            "base_addr": EVG_REG_BASE+180+2*off+0,
#            "data_width": 8,
#            "sign": "unsigned",
#        }
#        R[f"EVG:SEQ:{seq}:hw:f"] = {
#            "access": "w",
#            "addr_width": 0,
#            "base_addr": EVG_REG_BASE+180+2*off+1,
#            "data_width": 8,
#            "sign": "unsigned",
#        }
#        R[f"EVG:SEQ:{seq}:pattern"] = {
#            "access": "w",
#            "addr_width": seqAddrWidth+1,
#            "base_addr": EVG_REG_BASE+8192*seq, # seq1 @8192
#            "data_width": 32,
#            "sign": "unsigned",
#        }
#
#    for addr, rx in enumerate(range(1, rxCount+1), EVG_REG_BASE+200):
#        R[f"EVG:LINK:{rx}:latency"] = {
#            "access": "r",
#            "addr_width": 0,
#            "base_addr": addr,
#            "data_width": 8,
#            "sign": "unsigned",
#        }
    return R

def evt_merge():
    R = base_build()
    R.update(mpsLocal_build(MPS_REG_BASE=100000,
                            mpsOutputCount=8))
    R.update(ospreyEVG.ospreyEVG_build(
        EVG_REG_BASE=1000000,
        timerCount=8,
        hwTriggerCount=8,
        seqBankCount=8,
        seqAddrWidth=11,
    ))
    R.update(ospreyEVR.ospreyEVR_build(
        EVR_REG_BASE=1100000,
        hwOutputCount=8,
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
