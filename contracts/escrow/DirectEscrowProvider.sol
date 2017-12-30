pragma solidity 0.4.18;

import "zeppelin-solidity/contracts/token/ERC20.sol";

import "./EscrowProvider.sol";

/**
 * @title DirectEscrowProvider
 * @author Project Wyvern Developers
 */
contract DirectEscrowProvider {
  
    function DirectEscrowProvider () public {
    }

    function holdInEscrow(bytes32, address, address seller, ERC20 token, uint price) public returns (bool) {
        require(token.transferFrom(msg.sender, this, price));
        token.transfer(seller, price);
        return true;
    }

    function requestRelease(bytes32) pure public returns (bool) {
        return false;
    }    

    function releaseEscrow(bytes32) pure public returns (bool) {
        return false;
    }

    function disputeEscrow(bytes32) pure public returns (bool) {
        return false;
    }

}
