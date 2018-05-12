/*

  << Test Static Calls >>

*/

pragma solidity 0.4.23;

/**
  * @title TestStatic
  * @author Project Wyvern Developers
  */
contract TestStatic {

    /**
      * @dev Initialize contract
      */
    constructor () public {
    }

    function alwaysSucceed()
        public
        pure
    {
        require(true);
    }

    function alwaysFail()
        public
        pure
    {
        require(false);
    }

    function requireMinimumLength(bytes calldata)
        public
        pure
    {
        require(calldata.length > 2);
    }

}
