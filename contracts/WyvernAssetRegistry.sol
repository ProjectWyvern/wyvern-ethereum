/*

  << Project Wyvern Asset Registry >>

*/

pragma solidity 0.4.18;

import "./registry/AssetRegistry.sol";

/**
 * @title WyvernAssetRegistry
 * @author Project Wyvern Developers
 */
contract WyvernAssetRegistry is AssetRegistry {

    string public constant name = "Project Wyvern Asset Registry";

    function WyvernAssetRegistry ()
        public
    {
    }     

}
