#!/bin/sh

yarn flatten

alias oyente="docker run -v $(pwd):/opt luongnguyen/oyente /oyente/oyente/oyente.py"

for contract in $(ls temp/); do
  echo "Analyzing $contract with Mythril..."
  myth -x temp/$contract
  echo "Analyzing $contract with Oyente..."
  oyente -s /opt/temp/$contract
done
