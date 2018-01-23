/*

  << Test Lazy Bank >>

*/

pragma solidity 0.4.18;

import "./common/LazyBank.sol";

/**
 * @title TestBank
 * @author Project Wyvern Developers
 */
contract TestBank is LazyBank {

    string public constant name = "Test Bank";

    function TestBank () public {
    }

}
