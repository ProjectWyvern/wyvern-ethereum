pragma solidity 0.4.18;

import "zeppelin-solidity/contracts/token/ERC20.sol";

/**
 * @title EscrowProvider
 * @author Project Wyvern Developers
 */
contract EscrowProvider {
  
    function holdInEscrow(uint id, address buyer, address seller, ERC20 token, uint price) public returns (bool);

    function requestRelease(uint id) public returns (bool);

    function releaseEscrow(uint id) public returns (bool);

    function disputeEscrow(uint id) public returns (bool);

}
