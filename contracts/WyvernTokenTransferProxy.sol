/*

  << Project Wyvern Token Transfer Proxy >.

*/

pragma solidity 0.4.18;

import "./registry/TokenTransferProxy.sol";

contract WyvernTokenTransferProxy is TokenTransferProxy {

    function WyvernTokenTransferProxy (ProxyRegistry registryAddr)
        public
    {
        registry = registryAddr;
    }

}
