/*

  << Test Static Calls >>

*/

pragma solidity 0.4.18;

/**
  * @title TestStatic
  * @author Project Wyvern Developers
  */
contract TestStatic {

    /**
      * @dev Initialize contract
      */
    function TestStatic () public {
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

}
