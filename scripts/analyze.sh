#!/bin/sh

yarn flatten

alias oyente="docker run -v $(pwd):/opt luongnguyen/oyente /oyente/oyente/oyente.py"

for contract in $(ls temp/); do
  echo "Analyzing $contract..."
  oyente -s /opt/temp/$contract
done
