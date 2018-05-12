/*

  << Project Wyvern DAO >>

*/

pragma solidity 0.4.23;

import "./dao/DelegatedShareholderAssociation.sol";

/**
 * @title WyvernDAO
 * @author Project Wyvern Developers
 */
contract WyvernDAO is DelegatedShareholderAssociation {

    string public constant name = "Project Wyvern DAO";

    uint public constant TOKEN_DECIMALS                     = 18;
    uint public constant REQUIRED_SHARES_TO_BE_BOARD_MEMBER = 2000 * (10 ** TOKEN_DECIMALS); // set to ~ 0.1% of supply
    uint public constant MINIMUM_QUORUM                     = 200000 * (10 ** TOKEN_DECIMALS); // set to 10% of supply
    uint public constant DEBATE_PERIOD_MINUTES              = 60 * 24 * 3; // set to 3 days

    constructor (ERC20 sharesAddress) public {
        sharesTokenAddress = sharesAddress;
        requiredSharesToBeBoardMember = REQUIRED_SHARES_TO_BE_BOARD_MEMBER;
        minimumQuorum = MINIMUM_QUORUM;
        debatingPeriodInMinutes = DEBATE_PERIOD_MINUTES;
        tokenLocker = new TokenLocker(sharesAddress);
    }

}
