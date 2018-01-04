/*

  User registry. Keeps mutable usernames and a mapping of AuthenticatedProxy contracts. 
  
  Abstracted away from the Exchange so that other contracts can utilize the same username mappings and authenticated proxies.

*/

pragma solidity 0.4.19;

import "./AuthenticatedProxy.sol";

contract Registry {

    /* Authenticated proxies. */
    mapping(address => AuthenticatedProxy) public proxies;

    /* Usernames. */
    mapping(address => string) public usernames;

    /* Reverse usernames. */
    mapping(string => address) reverseUsernames;

    function reverseUsername(string username) public view returns (address) {
        return reverseUsernames[username];
    }

    function changeUsername(string newUsername) public {
        require(proxies[msg.sender] != address(0));
        require(reverseUsernames[newUsername] == address(0));
        string memory oldUsername = usernames[msg.sender];
        delete reverseUsernames[oldUsername];
        usernames[msg.sender] = newUsername;
        reverseUsernames[newUsername] = msg.sender;
    }

    function register(string username, address auth) public returns (AuthenticatedProxy proxy) {
        require(proxies[msg.sender] == address(0));
        require(reverseUsernames[username] == address(0));
        usernames[msg.sender] = username;
        reverseUsernames[username] = msg.sender;
        proxy = new AuthenticatedProxy(msg.sender, auth);
        proxies[msg.sender] = proxy;
        return proxy;
    }

}
