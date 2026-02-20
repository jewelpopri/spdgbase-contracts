/**
 *Submitted for verification at basescan.org on 2026-02-02
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * SpaceDoge Base (SPDGBASE)
 * Clean ERC20 - single file, no imports
 * - No tax
 * - No blacklist
 * - No pause
 * - No mint after deployment
 * - 100B minted once to deployer
 */
contract SpaceDogeBase {
    string public name = "SpaceDoge Base";
    string public symbol = "SPDGBASE";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        uint256 supply = 100_000_000_000 * (10 ** uint256(decimals));
        totalSupply = supply;
        balanceOf[msg.sender] = supply;
        emit Transfer(address(0), msg.sender, supply);
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= value, "ALLOWANCE_TOO_LOW");

        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - value;
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }

        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0), "TO_ZERO_ADDRESS");
        uint256 bal = balanceOf[from];
        require(bal >= value, "BALANCE_TOO_LOW");

        unchecked {
            balanceOf[from] = bal - value;
            balanceOf[to] += value;
        }

        emit Transfer(from, to, value);
    }
}
