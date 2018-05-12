/*

  << Test DAO (since we need a DAO controlled by a token that we can send around in tests) >>

*/

pragma solidity 0.4.23;

import "./dao/DelegatedShareholderAssociation.sol";

/**
 * @title TestDAO
 * @author Project Wyvern Developers
 */
contract TestDAO is DelegatedShareholderAssociation {

    string public constant name = "Test DAO";

    uint public constant TOKEN_DECIMALS                     = 18;
    uint public constant REQUIRED_SHARES_TO_BE_BOARD_MEMBER = 2000 * (10 ** 18); // set to ~ 0.1% of supply

    constructor (ERC20 sharesAddress) public {
        sharesTokenAddress = sharesAddress;
        requiredSharesToBeBoardMember = REQUIRED_SHARES_TO_BE_BOARD_MEMBER;
        minimumQuorum = 1000 * (10 ** TOKEN_DECIMALS);
        debatingPeriodInMinutes = 0;
        tokenLocker = new TokenLocker(sharesAddress);
    }

}
