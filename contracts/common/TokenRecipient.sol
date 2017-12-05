pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/token/ERC20.sol";

contract TokenRecipient {
    event ReceivedEther(address sender, uint amount);
    event ReceivedTokens(address _from, uint256 _value, address _token, bytes _extraData);

    /**
     * @dev Receive tokens and generate a log event
     * @param _from Address from which to transfer tokens
     * @param _value Amount of tokens to transfer
     * @param _token Address of token
     * @param _extraData Additional data to log
     */
    function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) public {
        ERC20 t = ERC20(_token);
        require(t.transferFrom(_from, this, _value));
        ReceivedTokens(_from, _value, _token, _extraData);
    }

    /**
     * @dev Receive Ether and generate a log event
     */
    function () payable public {
        ReceivedEther(msg.sender, msg.value);
    }
}
