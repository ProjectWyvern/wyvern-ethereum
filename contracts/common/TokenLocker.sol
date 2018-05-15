/*

  Contract to allow an owning contract to receive tokens (ERC20, not ERC223), transfer them at will, and do absolutely nothing else.
  
  Used to allow DAO shareholders to lock tokens for vote delegation but prevent the DAO from doing anything with the locked tokens.

  Much thanks to @adamkolar on Github - https://github.com/ProjectWyvern/wyvern-ethereum/issues/4

*/

pragma solidity 0.4.23;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

/**
 * @title TokenLocker
 * @author Project Wyvern Developers
 */
contract TokenLocker {
    
    address public owner;

    ERC20 public token;

    /**
     * @dev Create a new TokenLocker contract
     * @param tokenAddr ERC20 token this contract will be used to lock
     */
    constructor (ERC20 tokenAddr) public {
        owner = msg.sender;
        token = tokenAddr;
    }

    /** 
     *  @dev Call the ERC20 `transfer` function on the underlying token contract
     *  @param dest Token destination
     *  @param amount Amount of tokens to be transferred
     */
    function transfer(address dest, uint amount) public returns (bool) {
        require(msg.sender == owner);
        return token.transfer(dest, amount);
    }

}
