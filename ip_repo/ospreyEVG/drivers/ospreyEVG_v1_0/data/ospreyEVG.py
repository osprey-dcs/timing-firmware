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

# Create JSON file fragment for EVG registers

def ospreyEVG_emitJSON(EVG_REG_BASE=1000000, \
                       timerCount=2, \
                       hwTriggerCount=4, \
                       seqBankCount=4, \
                       seqAddrWidth=11,
                       rxCount=8):
    # Per EVG
    evg = ( """  "EVG:status": {
        "access": "r",
        "addr_width": 0,
        "base_addr": %d,
        "data_width": 32,
        "sign": "unsigned"
      },""",
      """  "EVG:config": {
        "access": "r",
        "addr_width": 0,
        "base_addr": %d,
        "data_width": 32,
        "sign": "unsigned"
      },""",
      """ "EVG:hbDivisor": {
        "access": "w",
        "addr_width": 0,
        "base_addr": %d,
        "data_width": 32,
        "sign": "unsigned"
      },""",
      """ "EVG:swEvent": {
        "access": "w",
        "addr_width": 0,
        "base_addr": %d,
        "data_width": 8,
        "sign": "unsigned"
      },""",
      """ "EVG:SEQ:arm": {
        "access": "w",
        "addr_width": 0,
        "base_addr": %d,
        "data_width": 8,
        "sign": "unsigned"
      },""",
      """ "EVG:SEQ:disarm": {
        "access": "w",
        "addr_width": 0,
        "base_addr": %d,
        "data_width": 8,
        "sign": "unsigned"
      },""",
      """ "EVG:SEQ:swTrig": {
        "access": "w",
        "addr_width": 0,
        "base_addr": %d,
        "data_width": 8,
        "sign": "unsigned"
      },""",
      """ "EVG:SEQ:cancel": {
        "access": "w",
        "addr_width": 0,
        "base_addr": %d,
        "data_width": 32,
        "sign": "unsigned"
      },""",
      """ "EVG:MAP:hwTrig": {
        "access": "rw",
        "addr_width": 0,
        "base_addr": %d,
        "data_width": 32,
        "sign": "unsigned"
      },""",
      """ "EVG:MAP:dbus": {
        "access": "rw",
        "addr_width": 0,
        "base_addr": %d,
        "data_width": 32,
        "sign": "unsigned"
      },""")

    r = EVG_REG_BASE
    for j in evg:
        print(j % (r))
        r += 1
    
    # Per timer
    template = """  "EVG:TMR:%d:event": {
        "access": "w",
        "addr_width": 0,
        "base_addr": %d,
        "data_width": 8,
        "sign": "unsigned"
      },
      "EVG:TMR:%d:divisor": {
        "access": "w",
        "addr_width": 0,
        "base_addr": %d,
        "data_width": 32,
        "sign": "unsigned"
      },"""
    for i in range(0, timerCount):
        print(template % (i+1, EVG_REG_BASE+100+i, i+1, EVG_REG_BASE+120+i))
    
    # Per hardware trigger
    template = """  "EVG:TRG:%c%d:ev": {
        "access": "w",
        "addr_width": 0,
        "base_addr": %d,
        "data_width": 8,
        "sign": "unsigned"
      },"""
    r = EVG_REG_BASE + 140
    for i in range(0, hwTriggerCount):
        for e in ('r', 'f'):
            print(template % (e, i+1, r))
            r += 1
    
    # Per sequencer bank hardware trigger
    template = """  "EVG:SEQ:%d:hw:%c": {
        "access": "w",
        "addr_width": 0,
        "base_addr": %d,
        "data_width": 8,
        "sign": "unsigned"
      },"""
    r = EVG_REG_BASE + 180
    for i in range(0, seqBankCount):
        for e in ('r', 'f'):
            print(template % (i+1, e, r))
            r += 1
    
    # Per latency measurement receiver
    template = """  "EVG:LINK:%d:latency": {
        "access": "r",
        "addr_width": 0,
        "base_addr": %d,
        "data_width": 8,
        "sign": "unsigned"
      },"""
    r = EVG_REG_BASE + 200
    for i in range(0, rxCount):
        print(template % (i+1, r))
        r += 1
    
    # Per sequencer bank
    template = """  "EVG:SEQ:%d:pattern": {
        "access": "w",
        "addr_width": %d,
        "base_addr": %d,
        "data_width": 32,
        "sign": "unsigned"
      },"""
    r = EVG_REG_BASE + 8192
    for i in range(0, seqBankCount):
        print(template % (i+1, seqAddrWidth+1, r))
        r += 8192

#############################################################################
if __name__ == "__main__":
    ospreyEVG_emitJSON()
