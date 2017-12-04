#!/bin/sh

echo 'Warning: at the moment, this script does *not* autodetect new Solidity source files; you must edit it manually to add a new contract.'
echo 'Script temporarily disabled!'

exit 0

# this is too buggy, need to update that library or use something else

node node_modules/solidity-static-analysis/analyse.js \
  -s contracts/token/DelayedReleaseToken.sol \
  -s contracts/token/UTXORedeemableToken.sol \
  -s contracts/WyvernToken.sol
#  -s contracts/dao/DelegatedShareholderAssociation.sol \
#  -s contracts/WyvernDAO.sol
