#!/bin/sh

set -ex

IP="192.168.79.12"
case "$#" in
    1)  IP="$1" ;;
esac

PYTHONPATH="$HOME/src/Osprey/src/Firmware/bedrock/projects/common" python -m leep.cli -d "leep://$IP" json
