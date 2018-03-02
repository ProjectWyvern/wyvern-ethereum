/*

  << Project Wyvern DAO Proxy >>

*/

pragma solidity 0.4.18;

import "./dao/DelegateProxy.sol";

/**
 * @title WyvernDAOProxy
 * @author Project Wyvern Developers
 */
contract WyvernDAOProxy is DelegateProxy {

    function WyvernDAOProxy ()
        public
    {
        owner = msg.sender;
    }

}
