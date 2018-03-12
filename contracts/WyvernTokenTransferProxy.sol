/*

  << Project Wyvern Token Transfer Proxy >.

*/

pragma solidity 0.4.19;

import "./registry/TokenTransferProxy.sol";

contract WyvernTokenTransferProxy is TokenTransferProxy {

    function WyvernTokenTransferProxy (ProxyRegistry registryAddr)
        public
    {
        registry = registryAddr;
    }

}
