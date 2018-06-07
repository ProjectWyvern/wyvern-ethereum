/*

  WyvernOwnableDelegateProxy

*/

pragma solidity 0.4.23;

import "./proxy/OwnedUpgradeabilityProxy.sol";

contract WyvernOwnableDelegateProxy is OwnedUpgradeabilityProxy {

    constructor(address owner, string initialVersion, address initialImplementation)
        public
    {
        _upgradeTo(initialVersion, initialImplementation);
        setUpgradeabilityOwner(owner);
    }

}
