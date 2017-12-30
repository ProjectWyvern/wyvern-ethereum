pragma solidity 0.4.18;

/**
 * @title ArrayUtils
 * @author Project Wyvern Developers
 */
library ArrayUtils {

    function arrayCopy(bytes arr, bytes rep, uint start) 
        pure
        internal
        returns (bytes)
    {
        for (uint i = 0; i < rep.length; i++) {
            arr[i + start] = rep[i];
        }
        return arr;
    }

    function toBytes(address a)
        pure
        internal
        returns (bytes b)
    {
        assembly {
            let m := mload(0x40)
            mstore(add(m, 20), xor(0x140000000000000000000000000000000000000000, a))
            mstore(0x40, add(m, 52))
            b := m
        }
    }

}
