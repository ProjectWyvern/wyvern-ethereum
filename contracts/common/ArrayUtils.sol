pragma solidity ^0.4.18;

/**
 * @title ArrayUtils
 * @author Project Wyvern Developers
 */
library ArrayUtils {

    function arrayCopy(bytes arr, bytes rep, uint start) internal pure returns (bytes) {
        for (uint i = 0; i < rep.length; i++) {
            arr[i + start] = rep[i];
        }
        return arr;
    }

}
