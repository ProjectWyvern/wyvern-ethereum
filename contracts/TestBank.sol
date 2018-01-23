/*

  << Test Lazy Bank >>

*/

pragma solidity 0.4.18;

import "./common/LazyBank.sol";

import "zeppelin-solidity/contracts/token/ERC20.sol";

/**
 * @title TestBank
 * @author Project Wyvern Developers
 */
contract TestBank is LazyBank {

    string public constant name = "Test Bank";

    function TestBank () public {
    }

    function _credit(address user, ERC20 token, uint amount)
        public
    {
        credit(user, token, amount);
    }

    function _lazyDebit(address user, ERC20 token, uint amount)
        public
    {
        lazyDebit(user, token, amount);
    }

    function _transferTo(address from, address to, ERC20 token, uint amount)
        public
    {
        transferTo(from, to, token, amount);
    }
    
    function _lazyLock(address user, ERC20 token, uint amount)
        public
    {
        lazyLock(user, token, amount);
    }
    
    function _unlock(address user, ERC20 token, uint amount)
        public
    {
        unlock(user, token, amount);
    }

}
