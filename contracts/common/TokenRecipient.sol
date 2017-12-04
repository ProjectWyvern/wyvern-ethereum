pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/token/ERC20.sol";

contract TokenRecipient {
    event ReceivedEther(address sender, uint amount);
    event ReceivedTokens(address _from, uint256 _value, address _token, bytes _extraData);

    function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) public {
        ERC20 t = ERC20(_token);
        require(t.transferFrom(_from, this, _value));
        ReceivedTokens(_from, _value, _token, _extraData);
    }

    function () payable  public {
        ReceivedEther(msg.sender, msg.value);
    }
}
