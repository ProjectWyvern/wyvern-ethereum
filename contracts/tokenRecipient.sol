pragma solidity ^0.4.15;

import 'zeppelin-solidity/contracts/token/ERC20.sol';

contract tokenRecipient {
    event receivedEther(address sender, uint amount);
    event receivedTokens(address _from, uint256 _value, address _token, bytes _extraData);

    function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData){
        ERC20 t = ERC20(_token);
        require(t.transferFrom(_from, this, _value));
        receivedTokens(_from, _value, _token, _extraData);
    }

    function () payable {
        receivedEther(msg.sender, msg.value);
    }
}
