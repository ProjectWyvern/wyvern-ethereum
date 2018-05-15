/*

  Delayed release token - a token which delays initial mint of a specified amount to allow an address to be provided after the token contract is instantiated.

  Used in our case to allow the Wyvern token to be instantiated, then the Wyvern DAO instantiated using the Wyvern token as the share token, then an amount of WYV to be minted to the DAO.

*/

pragma solidity 0.4.23;

import "openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol";

/**
  * @title DelayedReleaseToken
  * @author Project Wyvern Developers
  */
contract DelayedReleaseToken is StandardToken {

    /* Temporary administrator address, only used for the initial token release, must be initialized by token constructor. */
    address temporaryAdmin;

    /* Whether or not the delayed token release has occurred. */
    bool hasBeenReleased = false;

    /* Number of tokens to be released, must be initialized by token constructor. */
    uint numberOfDelayedTokens;

    /* Event for convenience. */
    event TokensReleased(address destination, uint numberOfTokens);

    /**
     * @dev Release the previously specified amount of tokens to the provided address
     * @param destination Address for which tokens will be released (minted) 
     */
    function releaseTokens(address destination) public {
        require((msg.sender == temporaryAdmin) && (!hasBeenReleased));
        hasBeenReleased = true;
        balances[destination] = numberOfDelayedTokens;
        emit Transfer(address(0), destination, numberOfDelayedTokens); 
        emit TokensReleased(destination, numberOfDelayedTokens);
    }

}
