#!/usr/bin/env python

#
# MIT License
#
# Copyright (c) 2025 Osprey DCS
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

from collections import OrderedDict
import json

# Create JSON file fragment for EVG registers

def ospreyEVG_build(EVG_REG_BASE=1000000,
                    timerCount=2,
                    hwTriggerCount=4,
                    seqBankCount=4,
                    seqAddrWidth=11,
                    rxCount=8):
    R = {
        "EVG:status": {
            "access": "r",
            "addr_width": 0,
            "base_addr": EVG_REG_BASE + 0,
            "data_width": 32,
            "sign": "unsigned",
        },
        "EVG:config": {
            "access": "r",
            "addr_width": 0,
            "base_addr": EVG_REG_BASE + 1,
            "data_width": 32,
            "sign": "unsigned",
        },
        "EVG:hbDivisor": {
            "access": "w",
            "addr_width": 0,
            "base_addr": EVG_REG_BASE + 2,
            "data_width": 32,
            "sign": "unsigned",
        },
        "EVG:swEvent": {
            "access": "w",
            "addr_width": 0,
            "base_addr": EVG_REG_BASE + 3,
            "data_width": 8,
            "sign": "unsigned",
        },
        "EVG:SEQ:arm": {
            "access": "w",
            "addr_width": 0,
            "base_addr": EVG_REG_BASE + 4,
            "data_width": 8,
            "sign": "unsigned",
        },
        "EVG:SEQ:disarm": {
            "access": "w",
            "addr_width": 0,
            "base_addr": EVG_REG_BASE + 5,
            "data_width": 8,
            "sign": "unsigned",
        },
        "EVG:SEQ:swTrig": {
            "access": "w",
            "addr_width": 0,
            "base_addr": EVG_REG_BASE + 6,
            "data_width": 8,
            "sign": "unsigned",
        },
        "EVG:SEQ:cancel": {
            "access": "w",
            "addr_width": 0,
            "base_addr": EVG_REG_BASE + 7,
            "data_width": 32,
            "sign": "unsigned",
        },
        "EVG:MAP:hwTrig": {
            "access": "rw",
            "addr_width": 0,
            "base_addr": EVG_REG_BASE + 8,
            "data_width": 32,
            "sign": "unsigned",
        },
        "EVG:MAP:dbus": {
            "access": "rw",
            "addr_width": 0,
            "base_addr": EVG_REG_BASE + 9,
            "data_width": 32,
            "sign": "unsigned",
        },
    }

    for addr, tmr in enumerate(range(1, timerCount+1), EVG_REG_BASE+100):
        R[f"EVG:TMR:{tmr}:event"] = {
            "access": "w",
            "addr_width": 0,
            "base_addr": addr,
            "data_width": 8,
            "sign": "unsigned",
        }

    for addr, tmr in enumerate(range(1, timerCount+1), EVG_REG_BASE+120):
        R[f"EVG:TMR:{tmr}:divisor"] = {
            "access": "w",
            "addr_width": 0,
            "base_addr": addr,
            "data_width": 32,
            "sign": "unsigned",
        }

    for off, trg in enumerate(range(1, hwTriggerCount+1)):
        R[f"EVG:TRG:r{trg}:ev"] = {
            "access": "w",
            "addr_width": 0,
            "base_addr": EVG_REG_BASE+140+2*off+0,
            "data_width": 8,
            "sign": "unsigned",
        }
        R[f"EVG:TRG:f{trg}:ev"] = {
            "access": "w",
            "addr_width": 0,
            "base_addr": EVG_REG_BASE+140+2*off+1,
            "data_width": 8,
            "sign": "unsigned",
        }

    for off, seq in enumerate(range(1, seqBankCount+1)):
        R[f"EVG:SEQ:{seq}:hw:r"] = {
            "access": "w",
            "addr_width": 0,
            "base_addr": EVG_REG_BASE+180+2*off+0,
            "data_width": 8,
            "sign": "unsigned",
        }
        R[f"EVG:SEQ:{seq}:hw:f"] = {
            "access": "w",
            "addr_width": 0,
            "base_addr": EVG_REG_BASE+180+2*off+1,
            "data_width": 8,
            "sign": "unsigned",
        }
        R[f"EVG:SEQ:{seq}:pattern"] = {
            "access": "w",
            "addr_width": seqAddrWidth+1,
            "base_addr": EVG_REG_BASE+8192*seq, # seq1 @8192
            "data_width": 32,
            "sign": "unsigned",
        }

    for addr, rx in enumerate(range(1, rxCount+1), EVG_REG_BASE+200):
        R[f"EVG:LINK:{rx}:latency"] = {
            "access": "r",
            "addr_width": 0,
            "base_addr": addr,
            "data_width": 8,
            "sign": "unsigned",
        }


    return R

if __name__ == "__main__":
    print(json.dumps(ospreyEVG_build(), indent=2))
