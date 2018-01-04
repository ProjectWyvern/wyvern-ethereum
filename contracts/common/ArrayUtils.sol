pragma solidity 0.4.19;

/**
 * @title ArrayUtils
 * @author Project Wyvern Developers
 */
library ArrayUtils {

    function arrayCopy(bytes arr, bytes rep, uint start, uint length) 
        pure
        internal
        returns (bytes)
    {
        require(rep.length == length);
        for (uint i = 0; i < length; i++) {
            arr[i + start] = rep[i];
        }
        return arr;
    }

    function arrayEq(bytes a, bytes b)
        pure
        internal
        returns (bool)
    {
        if (a.length != b.length) {
            return false;
        }
        for (uint i = 0; i < a.length; i++) {
            if (a[i] != b[i]) {
                return false;
            }
        }
        return true;
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
