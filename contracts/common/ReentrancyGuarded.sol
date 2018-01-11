pragma solidity 0.4.18;

/**
 * @title ReentrancyGuarded
 * @author Project Wyvern Developers
 */
contract ReentrancyGuarded {

    bool reentrancyLock = false;

    modifier reentrancyGuard {
        if (reentrancyLock) {
            revert();
        }
        reentrancyLock = true;
        _;
        reentrancyLock = false;
    }

}
