#!/bin/sh

rm -rf temp
mkdir -p temp

alias flatten="solidity_flattener --solc-paths zeppelin-solidity=$(pwd)/node_modules/zeppelin-solidity"

flatten contracts/WyvernToken.sol --output temp/WyvernTokenFlattened.sol
flatten contracts/WyvernDAO.sol --output temp/WyvernDAOFlattened.sol
flatten contracts/WyvernExchange.sol --output temp/WyvernExchangeFlattened.sol
