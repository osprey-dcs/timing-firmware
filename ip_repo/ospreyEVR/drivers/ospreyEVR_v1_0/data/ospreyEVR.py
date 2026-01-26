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

# Create JSON file fragment for EVR registers

def ospreyEVR_emitJSON(EVR_REG_BASE=1100000, hwOutputCount=8):
    evr = ("""  "EVR:status": {
        "access": "r",
        "addr_width": 0,
        "base_addr": %d,
        "data_width": 32,
        "sign": "unsigned"
      },""",)
    r = EVR_REG_BASE
    for j in evr:
        print(j % (r))
        r += 1

    template = """  "EVR:evnt%03d:action": {
        "access": "w",
        "addr_width": 0,
        "base_addr": %d,
        "data_width": 18,
        "sign": "unsigned"
      },"""
    r = EVR_REG_BASE + 101
    for e in range(1,127):
        print(template % (e, r))
        r += 1
    
    out = ("""  "EVR:out%d:source": {
        "access": "w",
        "addr_width": 0,
        "base_addr": %d,
        "data_width": 8,
        "sign": "unsigned"
      },""",
      """  "EVR:pls%d:delay": {
        "access": "w",
        "addr_width": 0,
        "base_addr": %d,
        "data_width": 32,
        "sign": "unsigned"
      },""",
      """  "EVR:pls%d:width": {
        "access": "w",
        "addr_width": 0,
        "base_addr": %d,
        "data_width": 32,
        "sign": "unsigned"
      },""")
    rb = EVR_REG_BASE + 400
    for j in out:
        r = rb
        for i in range(0,hwOutputCount):
            print(j % (i+1, r))
            r += 1
        rb += 20


#############################################################################
if __name__ == "__main__":
    ospreyEVR_emitJSON()
