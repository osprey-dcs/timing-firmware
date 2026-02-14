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

# Create JSON file fragment for EVR registers

def ospreyEVR_build(EVR_REG_BASE=1100000, hwOutputCount=8):
    R = {
        "__metadata__": {
            "evrActionWidth": 18,
        },
        "EVR:status": {
            "access": "r",
            "addr_width": 0,
            "base_addr": EVR_REG_BASE,
            "data_width": 32,
            "sign": "unsigned",
        },
        "EVR:now": {
            "access": "r",
            "addr_width": 1, # 2
            "base_addr": EVR_REG_BASE+1,
            "data_width": 32,
            "sign": "unsigned",
        },
        "EVR:evnt:map": {
            "access": "rw",
            "addr_width": 8, # 256
            "base_addr": EVR_REG_BASE+100,
            "data_width": 18,
            "sign": "unsigned",
        },
    }

    for addr, idx in enumerate(range(1, hwOutputCount+1), EVR_REG_BASE+400):
        R[f"EVR:out{idx}:source"] = {
            "access": "w",
            "addr_width": 0,
            "base_addr": addr,
            "data_width": 8,
            "sign": "unsigned",
        }

    for addr, idx in enumerate(range(1, hwOutputCount+1), EVR_REG_BASE+420):
        R[f"EVR:pls{idx}:delay"] = {
            "access": "w",
            "addr_width": 0,
            "base_addr": addr,
            "data_width": 32,
            "sign": "unsigned",
        }

    for addr, idx in enumerate(range(1, hwOutputCount+1), EVR_REG_BASE+440):
        R[f"EVR:pls{idx}:width"] = {
            "access": "w",
            "addr_width": 0,
            "base_addr": addr,
            "data_width": 32,
            "sign": "unsigned",
        }

    return R

if __name__ == "__main__":
    print(json.dumps(ospreyEVR_build(), indent=2))
