#!/bin/sh

rm -rf temp
mkdir -p temp

alias flatten="solidity_flattener --solc-paths zeppelin-solidity=$(pwd)/node_modules/zeppelin-solidity"

flatten contracts/TestToken.sol --output temp/TestTokenFlattened.sol
flatten contracts/TestDAO.sol --output temp/TestDAOFlattened.sol
flatten contracts/WyvernToken.sol --output temp/WyvernTokenFlattened.sol
flatten contracts/WyvernDAO.sol --output temp/WyvernDAOFlattened.sol
flatten contracts/WyvernExchange.sol --output temp/WyvernExchangeFlattened.sol
flatten contracts/WyvernRegistry.sol --output temp/WyvernRegistryFlattened.sol
