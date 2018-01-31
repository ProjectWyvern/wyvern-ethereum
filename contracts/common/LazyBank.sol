/*

  LazyBank - keep user balances, support credit, debit, and locking, and minimize requisite token transfers whilst doing so.

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

    /**
     * Return the balance a user has of a token
     * 
     * @param user User address to query
     * @param token Token address to query
     * @return Balance of the user
     */
    function balanceFor(address user, ERC20 token)
        public
        view
        returns (uint)
    {
        return balances[user][token];
    }

    /**
     * Return the locked amount a user has of a token
     *
     * @param user User address to query
     * @param token Token address to query
     * @return Amount of tokens locked for the user
     */
    function lockedFor(address user, ERC20 token)
        public
        view
        returns (uint)
    {
        return locked[user][token];
    }

    /**
     * Returns the amount of a token a user could withdraw immediately
     * 
     * @param user User address to query
     * @param token Token address to query
     * @return Amount of tokens available for withdrawal
     */
    function availableFor(address user, ERC20 token)
        public
        view
        returns (uint)
    {
        return SafeMath.sub(balances[user][token], locked[user][token]);
    }

    /**
     * Deposit a specified amount of tokens for the sender
     *
     * @param token ERC20 token to deposit
     * @param amount Amount of tokens to deposit
     */
    function deposit(ERC20 token, uint amount)
        public
    {
        credit(msg.sender, token, amount);
        require(token.transferFrom(msg.sender, this, amount));
    }

    /**
     * Withdraw a specified amount of tokens belonging to the sender to a specified address
     *
     * @param token ERC20 token to withdraw
     * @param amount Amount of tokens to withdraw
     * @param dest Address to which to send the tokens
    */
    function withdraw(ERC20 token, uint amount, address dest)
        public
    {
        uint available = SafeMath.sub(balances[msg.sender][token], locked[msg.sender][token]);
        require(amount <= available);
        lazyDebit(msg.sender, token, amount);
        token.transfer(dest, amount); 
    }

    /**
     * Credit a user with a specified amount of a token
     *
     * @dev Internal only
     * @param user User address to credit
     * @param token ERC20 address to credit
     * @param amount Amount of tokens to credit
     */
    function credit(address user, ERC20 token, uint amount)
        internal
    {
        balances[user][token] = SafeMath.add(balances[user][token], amount);        
        Credited(user, token, amount);
    }

    /**
     * Lazy-debit a user a specified amount of a token
     * Uses internal balance if available, executes ERC20 transferFrom otherwise
     * 
     * @dev Internal only
     * @param user User address to debit
     * @param token ERC20 address to debit
     * @param amount Amount to debit
     */
    function lazyDebit(address user, ERC20 token, uint amount) 
        internal
    {
        uint available = SafeMath.sub(balances[user][token], locked[user][token]);
        if (available >= amount) {
            balances[user][token] = SafeMath.sub(balances[user][token], amount);
        } else {
            uint diff = SafeMath.sub(amount, available);
            balances[user][token] = 0;
            require(token.transferFrom(user, this, diff));
        }
        Debited(user, token, amount);
    }

    /**
     * Transfer balance of a token from one user to another
     *
     * @dev Internal only
     * @param from Address to debit
     * @param to Address to credit
     * @param token Token to transfer
     * @param amount Amount of tokens
     */
    function transferTo(address from, address to, ERC20 token, uint amount)
        internal
    {
        credit(to, token, amount);
        lazyDebit(from, token, amount);
    }

    /**
     * Lazy-lock an amount of a token for a user
     * Uses internal balance if available, executes ERC20 transferFrom otherwise
     *
     * @dev Internal only
     * @param user User address to lock for
     * @param token ERC20 address to lock
     * @param amount Amount of tokens to lock
     */
    function lazyLock(address user, ERC20 token, uint amount)
        internal
    {
        locked[user][token] = SafeMath.add(locked[user][token], amount);
        uint userLocked = locked[user][token];
        uint userBalance = balances[user][token];
        if (userLocked > userBalance) {
            uint diff = SafeMath.sub(userLocked, userBalance);
            balances[user][token] = SafeMath.add(userBalance, diff);
            require(token.transferFrom(user, this, diff));
        }
        Locked(user, token, amount);
    }

    /**
     * Unlock an amount of a token for a user
     *
     * @dev Internal only
     * @param user User address to unlock tokens for
     * @param token ERC20 address
     * @param amount Amount of tokens to unlock
     */
    function unlock(address user, ERC20 token, uint amount)
        internal
    {
        locked[user][token] = SafeMath.sub(locked[user][token], amount);
        require(locked[user][token] >= 0);
        Unlocked(user, token, amount);
    }

}
