/*

  << Project Wyvern Token Transfer Proxy >.

*/

pragma solidity 0.4.23;

import "./registry/TokenTransferProxy.sol";

contract WyvernTokenTransferProxy is TokenTransferProxy {

    constructor (ProxyRegistry registryAddr)
        public
    {
        registry = registryAddr;
    }

}
