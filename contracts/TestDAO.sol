/*

  << Test DAO (since we need a token that we can send around in tests) >>

*/

pragma solidity ^0.4.18;

import "./dao/DelegatedShareholderAssociation.sol";

/**
 * @title TestDAO
 * @author Project Wyvern Developers
 *
 *
 */
contract TestDAO is DelegatedShareholderAssociation {

    string public constant name = "Test DAO";

    function TestDAO (ERC20 sharesAddress, uint minimumSharesToPassAVote, uint minutesForDebate) public {
        sharesTokenAddress = sharesAddress;
        minimumQuorum = minimumSharesToPassAVote;
        debatingPeriodInMinutes = minutesForDebate;
    }

}
