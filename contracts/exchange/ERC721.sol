/* 

ERC721 (draft) non-fungible token interface. See https://github.com/ethereum/EIPs/issues/721.

*/

pragma solidity 0.4.18;

/**
 * @title ERC721
 * @author Project Wyvern Developers
 */
contract ERC721 {
    function totalSupply() public view returns (uint256 _totalSupply);
    function balanceOf(address _owner) public view returns (uint256 balance);
    function ownerOf(uint256 _tokenId) public view returns (address owner);
    function approve(address _to, uint256 _tokenId) public;
    function takeOwnership(uint256 _tokenId) public;
    function transfer(address _to, uint256 _tokenId) public;
}
