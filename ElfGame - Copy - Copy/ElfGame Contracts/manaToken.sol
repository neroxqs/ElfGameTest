// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Dodaj limit

contract Mana is ERC20, Ownable{

  mapping(address => bool) peopleAllowed;

  constructor() ERC20("Mana", "Mana") {
    peopleAllowed[msg.sender] = true;
  }

  function mint(address to, uint256 amount) external {
    require(peopleAllowed[msg.sender], "Only people allowed can mint");
    _mint(to, amount);
  }

  function burn(address from, uint256 amount) external {
    require(peopleAllowed[msg.sender], "Only people allowed can burn");
    _burn(from, amount);
  }

  function addController(address controller) external onlyOwner {
    peopleAllowed[controller] = true;
  }
  
  function removeController(address controller) external onlyOwner {
    peopleAllowed[controller] = false;
  }
}