README.md
# SPDGBASE – Base Network Expansion Layer

SPDGBASE is the structured expansion layer of the SPDG ecosystem, built on Base Network.

---

## Network
Base

---

## Supply Structure

Total Supply: 100,000,000,000 SPDGBASE  
Reserve: 60,000,000,000 locked until Aug 21, 2027  
Presale Allocation: 20,000,000,000  
DEX Liquidity: 5,000,000,000  
Operations & Expansion: 15,000,000,000  

---

## Contracts

Token Contract:
0x8fAace17021f483f20071D43e22a6BecFCA42F9f

Presale Contract:
0xa70743af9a3B5002AE73F0c548c46C2259BBb370

Reserve Lock (Team Finance):
60,000,000,000 tokens

Lock Transaction:
0xee6895546c4c536831ad08c90d0a0406340394f7b60352525a6aef8e6f7cb97c

Lock Contract:
0x4F0Fd563BE89ec8C3e7D595bf3639128C0a7C33A

---

## Status
Structure Phase – Capital Formation

SPDGBASE focuses on disciplined liquidity, transparent allocation, and long-term ecosystem scaling.


Initial SPDGBASE documentation

Token contract .sol

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

 Presale contract .sol

/**
 *Submitted for verification at basescan.org on 2026-02-03
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title SPDGBASE Presale (USDC on Base)
 * @notice 40-day presale with 2 discount phases; tokens locked 90 days after presale ends.
 * @dev Single-file, no imports. Accepts USDC (6 decimals). SPDGBASE token assumed 18 decimals.
 *
 * PHASE A (Day 1-20): 50% discount => $0.0005 per token
 * PHASE B (Day 21-40): 25% discount => $0.00075 per token
 *
 * - Hard cap: $10,000,000 USDC
 * - Max tokens for sale: 20,000,000,000 SPDGBASE
 * - Unsold tokens return to treasury immediately after presale ends (finalize)
 * - Claim unlock: 90 days after presale ends
 */
interface IERC20 {
    function balanceOf(address a) external view returns (uint256);
    function transfer(address to, uint256 amt) external returns (bool);
    function transferFrom(address from, address to, uint256 amt) external returns (bool);
}

contract SPDGBASEPresaleUSDC {
    // ====== CONSTANTS ======
    uint256 public constant TOKEN_DECIMALS = 1e18; // SPDGBASE assumed 18 decimals
    uint256 public constant USDC_DECIMALS  = 1e6;  // USDC assumed 6 decimals

    // Prices are in "micro-USDC per 1 token" (USDC has 6 decimals)
    // Public price reference: $0.001 => 1000 micro-USDC (NOT used for presale)
    uint256 public constant PRICE_PHASE_A_MICRO = 500; // $0.0005
    uint256 public constant PRICE_PHASE_B_MICRO = 750; // $0.00075

    // ====== CONFIG (IMMUTABLE) ======
    address public immutable owner;
    IERC20  public immutable token;    // SPDGBASE
    IERC20  public immutable usdc;     // USDC on Base
    address public immutable treasury; // SPDGBASE Treasury

    uint256 public immutable startTime;      // presale start
    uint256 public immutable phaseAEndTime;  // start + 20 days
    uint256 public immutable endTime;        // start + 40 days

    uint256 public immutable hardCapUSDC;       // 10,000,000 * 1e6
    uint256 public immutable maxTokensForSale;  // 20,000,000,000 * 1e18

    uint256 public immutable claimUnlockTime; // endTime + 90 days

    // ====== STATE ======
    uint256 public totalRaisedUSDC;  // in micro-USDC (6 decimals)
    uint256 public totalTokensSold;  // in token wei (18 decimals)
    bool    public finalized;

    mapping(address => uint256) public purchasedTokens; // claimable amount after lock

    // ====== EVENTS ======
    event Bought(address indexed buyer, uint256 usdcIn, uint256 tokensOut);
    event Finalized(uint256 usdcToTreasury, uint256 unsoldTokensToTreasury);
    event Claimed(address indexed buyer, uint256 tokensOut);

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    constructor(
        address tokenAddress,
        address usdcAddress,
        address treasuryAddress,
        uint256 startTimestamp
    ) {
        require(tokenAddress != address(0) && usdcAddress != address(0) && treasuryAddress != address(0), "ZERO_ADDR");

        owner = msg.sender;
        token = IERC20(tokenAddress);
        usdc = IERC20(usdcAddress);
        treasury = treasuryAddress;

        startTime = startTimestamp;
        phaseAEndTime = startTimestamp + 20 days;
        endTime = startTimestamp + 40 days;

        hardCapUSDC = 10_000_000 * USDC_DECIMALS;
        maxTokensForSale = 20_000_000_000 * TOKEN_DECIMALS;

        claimUnlockTime = endTime + 90 days;
    }

    // ====== VIEW HELPERS ======

    function currentPhase() external view returns (uint8) {
        if (block.timestamp < startTime) return 0; // not started
        if (block.timestamp < phaseAEndTime) return 1; // Phase A
        if (block.timestamp < endTime) return 2; // Phase B
        return 3; // ended
    }

    function currentPriceMicroUSDC() public view returns (uint256) {
        if (block.timestamp < phaseAEndTime) return PRICE_PHASE_A_MICRO;
        return PRICE_PHASE_B_MICRO;
    }

    // ====== BUY ======
    /**
     * @notice Buy SPDGBASE using USDC (Base). Tokens are locked until claimUnlockTime.
     * @param usdcAmount Amount of USDC in 6 decimals (micro-USDC).
     */
    function buy(uint256 usdcAmount) external {
        require(block.timestamp >= startTime, "NOT_STARTED");
        require(block.timestamp < endTime, "PRESALE_ENDED");
        require(!finalized, "FINALIZED");
        require(usdcAmount > 0, "ZERO_AMOUNT");

        // hard cap check
        require(totalRaisedUSDC + usdcAmount <= hardCapUSDC, "HARD_CAP");

        uint256 priceMicro = currentPriceMicroUSDC();

        // tokensOut (18 decimals) = usdcAmount(6) * 1e18 / priceMicro
        uint256 tokensOut = (usdcAmount * TOKEN_DECIMALS) / priceMicro;
        require(tokensOut > 0, "AMOUNT_TOO_SMALL");

        // token cap check (20B tokens max)
        require(totalTokensSold + tokensOut <= maxTokensForSale, "TOKEN_CAP");

        // pull USDC from buyer
        _safeTransferFrom(address(usdc), msg.sender, address(this), usdcAmount);

        // record purchase
        purchasedTokens[msg.sender] += tokensOut;
        totalRaisedUSDC += usdcAmount;
        totalTokensSold += tokensOut;

        emit Bought(msg.sender, usdcAmount, tokensOut);
    }

    // ====== FINALIZE ======
    /**
     * @notice Ends the presale and sends USDC to treasury + returns unsold tokens to treasury.
     * @dev Can be called after endTime. Once finalized, no more buying.
     */
    function finalize() external onlyOwner {
        require(block.timestamp >= endTime, "NOT_ENDED");
        require(!finalized, "ALREADY_FINALIZED");

        finalized = true;

        // 1) Send all raised USDC to treasury
        uint256 usdcBal = usdc.balanceOf(address(this));
        if (usdcBal > 0) {
            _safeTransfer(address(usdc), treasury, usdcBal);
        }

        // 2) Return unsold tokens to treasury immediately
        // Contract should be funded with maxTokensForSale before presale starts.
        // Unsold = tokenBalance - totalTokensSold
        uint256 tokenBal = token.balanceOf(address(this));
        require(tokenBal >= totalTokensSold, "INSUFFICIENT_TOKENS");

        uint256 unsold = tokenBal - totalTokensSold;
        if (unsold > 0) {
            _safeTransfer(address(token), treasury, unsold);
        }

        emit Finalized(usdcBal, unsold);
    }

    // ====== CLAIM ======
    /**
     * @notice Claim purchased tokens after lock (90 days after presale end).
     */
    function claim() external {
        require(finalized, "NOT_FINALIZED");
        require(block.timestamp >= claimUnlockTime, "LOCKED");

        uint256 amt = purchasedTokens[msg.sender];
        require(amt > 0, "NOTHING_TO_CLAIM");

        purchasedTokens[msg.sender] = 0;
        _safeTransfer(address(token), msg.sender, amt);

        emit Claimed(msg.sender, amt);
    }

    // ====== FUNDING HELPERS ======
    /**
     * @notice Returns how many SPDGBASE tokens should be deposited into this contract before presale.
     */
    function requiredTokenDeposit() external pure returns (uint256) {
        return 20_000_000_000 * TOKEN_DECIMALS;
    }

    // ====== SAFE TRANSFER HELPERS (NO IMPORTS) ======
    function _safeTransfer(address tokenAddr, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = tokenAddr.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FAILED");
    }

    function _safeTransferFrom(address tokenAddr, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = tokenAddr.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "TRANSFERFROM_FAILED");
    }
}
