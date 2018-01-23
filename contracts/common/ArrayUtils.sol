/*

  Various functions for manipulating arrays in Solidity.
  This library is completely inlined and does not need to be deployed or linked.

*/

pragma solidity 0.4.18;

/**
 * @title ArrayUtils
 * @author Project Wyvern Developers
 */
library ArrayUtils {

    /**
     * Replace bytes in an array with bytes in another array, guarded by a "bytemask"
     * 
     * @dev Mask must be 1/8th the size of the byte array. A 1-bit means the byte array can be changed.
     * @param array The original array
     * @param desired The target array
     * @param mask The mask specifying which bytes can be changed
     * @return The updated byte array (the parameter will be modified inplace)
     */
    function guardedArrayReplace(bytes array, bytes desired, bytes mask)
        pure
        internal
    {
        byte[8] memory bitmasks = [byte(2 ** 7), byte(2 ** 6), byte(2 ** 5), byte(2 ** 4), byte(2 ** 3), byte(2 ** 2), byte(2 ** 1), byte(2 ** 0)];
        require(array.length == desired.length);
        require(mask.length >= array.length / 8);
        for (uint i = 0; i < array.length; i++ ) {
            /* 1-bit means value can be changed. */
            bool masked = (mask[i / 8] & bitmasks[i % 8]) == 0;
            array[i] = masked ? array[i] : desired[i];
        }
    }

    /**
     * Test if two arrays are equal
     * 
     * @dev Arrays must be of equal length, otherwise will return false
     * @param a First array
     * @param b Second array
     * @return Whether or not all bytes in the arrays are equal
     */
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

    /**
     * Convert an address to bytes
     *
     * @param a Address to convert
     * @return The address as a byte array
     */
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
