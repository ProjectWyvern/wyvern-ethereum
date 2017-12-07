/*

  << Project Wyvern DAO >>

*/

pragma solidity ^0.4.18;

import "./dao/DelegatedShareholderAssociation.sol";

/**
 * @title WyvernDAO
 * @author Project Wyvern Developers
 *
 *
 */
contract WyvernDAO is DelegatedShareholderAssociation {

    string public constant name = "Project Wyvern DAO";

    uint public constant TOKEN_DECIMALS                     = 18;
    uint public constant REQUIRED_SHARES_TO_BE_BOARD_MEMBER = 2000 * (10 ** 18); // set to ~ 0.1% of supply

    function WyvernDAO (ERC20 sharesAddress, uint minimumSharesToPassAVote, uint minutesForDebate) public {
        sharesTokenAddress = sharesAddress;
        requiredSharesToBeBoardMember = REQUIRED_SHARES_TO_BE_BOARD_MEMBER;
        minimumQuorum = minimumSharesToPassAVote;
        debatingPeriodInMinutes = minutesForDebate;
    }

}
