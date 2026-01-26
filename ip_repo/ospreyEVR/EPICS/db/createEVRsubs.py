#!/usr/bin/env python

#
# The event receiver database substitutions file is lengthy.
# This script simplifies the process of creating it.
#

outputDriverCount = 8

# Create FEED-compatible substitution file
print(r'file "perEVRevent.template" {')
print(r'  pattern {P, PORT,   N }')
for e in range(1,127):
    print(r"  { \$(P),\$(PORT), %03d }" % (e))
print(r'}')
print(r'file "perEVRoutputDriver.template" {')
print(r'  pattern {P, PORT, N }')
for o in range(1,outputDriverCount+1):
    print(r"  { \$(P),\$(PORT), %d }" % (o))
print(r'}')
