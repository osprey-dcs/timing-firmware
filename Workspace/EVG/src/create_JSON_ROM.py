# Create JSON file that maps EPICS INP/OUT strings to register numbers

#############################################################################
# Header
print("{")

#############################################################################
# Event generator
import ospreyEVG
ospreyEVG.ospreyEVG_emitJSON(EVG_REG_BASE=1000000, \
                             timerCount=2, \
                             hwTriggerCount=8, \
                             seqBankCount=4, \
                             seqAddrWidth=11)

#############################################################################
# Event receiver
import ospreyEVR
ospreyEVR.ospreyEVR_emitJSON(EVR_REG_BASE=1100000, \
                             hwOutputCount=8)

#############################################################################
# Marble support

print("""  "FPGA:powerUp_": {
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
  "Marble:mgtRefClk0": {
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
  "Marble:U29": {
    "access": "r",
    "addr_width": 0,
    "base_addr": 132,
    "data_width": 16,
    "sign": "unsigned"
  },
  "Marble:U28": {
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
    "sign": "unsigned"
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
    "sign": "unsigned"
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
  "Marble:VCXO:SR": {
    "access": "r",
    "addr_width": 0,
    "base_addr": 292,
    "data_width": 32,
    "sign": "unsigned"
  },
  "Marble:VCXO:ASR": {
    "access": "r",
    "addr_width": 0,
    "base_addr": 293,
    "data_width": 32,
    "sign": "unsigned"
  },
  "Marble:VCXO:PPS": {
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
  }
}""")
