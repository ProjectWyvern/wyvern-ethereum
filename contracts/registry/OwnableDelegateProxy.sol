/*

  WyvernOwnableDelegateProxy

*/

pragma solidity 0.4.23;

import "./proxy/OwnedUpgradeabilityProxy.sol";

contract OwnableDelegateProxy is OwnedUpgradeabilityProxy {

    constructor(address owner, address initialImplementation)
        public
    {
        _upgradeTo(initialImplementation);
        setUpgradeabilityOwner(owner);
    }

}
