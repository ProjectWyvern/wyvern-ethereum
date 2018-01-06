/*

    LazyBank - keep user balances, support credit, debit, and locking, and minimize requisite token transfers.

    TODO
    - ERC223 support
    - Analyze for ERC223 reentrancy bugs

*/

pragma solidity 0.4.18;

import "zeppelin-solidity/contracts/token/ERC20.sol";
import "zeppelin-solidity/contracts/math/SafeMath.sol";

/**
 * @title LazyBank
 * @author Project Wyvern Developers
 */
contract LazyBank {

    /* Token balances, by owner, by token. */
    mapping(address => mapping(address => uint)) public balances;

    /* Locked tokens, by owner, by token. */
    mapping(address => mapping(address => uint)) public locked;

    event Credited(address indexed user, address indexed token, uint amount);
    event Debited(address indexed user, address indexed token, uint amount);
    event Locked(address indexed user, address indexed token, uint amount);
    event Unlocked(address indexed user, address indexed token, uint amount);

    function balanceFor(address user, ERC20 token)
        public
        view
        returns (uint)
    {
        return balances[user][token];
    }

    function lockedFor(address user, ERC20 token)
        public
        view
        returns (uint)
    {
        return locked[user][token];
    }

    function availableFor(address user, ERC20 token)
        public
        view
        returns (uint)
    {
        return balances[user][token] - locked[user][token];
    }

    function deposit(address user, ERC20 token, uint amount)
        public
    {
        require(msg.sender == user);
        credit(user, token, amount);
        require(token.transferFrom(user, this, amount));
    }

    function withdraw(address user, ERC20 token, uint amount)
        public
    {
        require(msg.sender == user);
        uint available = SafeMath.sub(balances[user][token], locked[user][token]);
        require(amount <= available);
        balances[user][token] = SafeMath.sub(balances[user][token], amount);
        token.transfer(user, amount); 
    }

    function credit(address user, ERC20 token, uint amount)
        internal
    {
        balances[user][token] = SafeMath.add(balances[user][token], amount);        
        Credited(user, token, amount);
    }

    function lazyDebit(address user, ERC20 token, uint amount) 
        internal
    {
        uint available = SafeMath.sub(balances[user][token], locked[user][token]);
        Debited(user, token, amount);
        if (available >= amount) {
            balances[user][token] = SafeMath.sub(balances[user][token], amount);
        } else {
            uint diff = SafeMath.sub(amount, available);
            balances[user][token] = 0;
            require(token.transferFrom(user, this, diff));
        }
    }

    function lazyLock(address user, ERC20 token, uint amount)
        internal
    {
        locked[user][token] = SafeMath.add(locked[user][token], amount);
        if (locked[user][token] > balances[user][token]) {
            uint diff = SafeMath.sub(locked[user][token], balances[user][token]);
            balances[user][token] = SafeMath.add(balances[user][token], diff);
            require(token.transferFrom(user, this, diff));
        }
        require(balances[user][token] >= locked[user][token]);
        Locked(user, token, amount);
    }

    function unlock(address user, ERC20 token, uint amount)
        internal
    {
        locked[user][token] = SafeMath.sub(locked[user][token], amount);
        require(locked[user][token] >= 0);
        Unlocked(user, token, amount);
    }

}
