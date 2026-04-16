// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../lib/openzeppelin-contracts/contracts/security/Pausable.sol";

/// @title ForgeVault - A yield-bearing ERC-4626 vault
/// @notice Users deposit MTK tokens and receive fvTokens that represent their share of the pool
/// @dev Implements ERC-4626 standard with yield strategy hooks and performance fees
contract ForgeVault is ERC4626, AccessControl, ReentrancyGuard, Pausable {
    // ========== CONSTANTS & ROLES ==========
    
    /// @dev Role allowed to harvest yield and execute strategies
    bytes32 public constant STRATEGIST_ROLE = keccak256("STRATEGIST_ROLE");
    
    /// @dev Role allowed to pause the contract in emergencies
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    /// @dev Maximum performance fee (5%)
    uint256 private constant MAX_FEE_BPS = 500;
    
    /// @dev Fee denominator (100% = 10000 basis points)
    uint256 private constant FEE_DENOMINATOR = 10000;
    
    // ========== STATE VARIABLES ==========
    
    /// @dev Performance fee in basis points (e.g., 100 = 1%)
    uint256 public performanceFeeBps;
    
    /// @dev Total yield earned over the lifetime of the vault
    uint256 public totalYieldEarned;
    
    /// @dev Address that receives performance fees
    address public feeRecipient;
    
    /// @dev Tracks assets at last harvest for yield calculation
    uint256 private _lastTotalAssets;
    
    // ========== EVENTS ==========
    
    /// @notice Emitted when yield is harvested and fees are taken
    /// @param yield The amount of yield generated since last harvest
    /// @param fee The amount taken as performance fee
    event YieldHarvested(uint256 indexed yield, uint256 indexed fee);
    
    /// @notice Emitted when performance fee is updated
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    
    /// @notice Emitted when fee recipient address is updated
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    
    /// @notice Emitted when a strategy is executed
    event StrategyExecuted(bytes data);
    
    // ========== CONSTRUCTOR ==========
    
    /// @notice Deploys the ForgeVault contract
    /// @param asset The underlying token (e.g., MyToken)
    /// @param feeRecipient_ Address that receives performance fees
    /// @param performanceFeeBps_ Initial performance fee in basis points (max 500 = 5%)
    constructor(
        IERC20 asset,
        address feeRecipient_,
        uint256 performanceFeeBps_
    ) ERC4626(asset) ERC20("Forge Vault Token", "fvToken") {
        require(feeRecipient_ != address(0), "ForgeVault: invalid fee recipient");
        require(performanceFeeBps_ <= MAX_FEE_BPS, "ForgeVault: fee too high (max 5%)");
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(STRATEGIST_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
        
        feeRecipient = feeRecipient_;
        performanceFeeBps = performanceFeeBps_;
        _lastTotalAssets = 0;
    }
    
    // ========== EXTERNAL FUNCTIONS ==========
    
    /// @notice Harvest yield from strategies and distribute performance fees
    /// @dev Can only be called by accounts with STRATEGIST_ROLE
    function harvest() external nonReentrant onlyRole(STRATEGIST_ROLE) whenNotPaused {
        uint256 currentAssets = totalAssets();
        uint256 previousAssets = _lastTotalAssets;
        
        // Calculate yield since last harvest
        if (currentAssets > previousAssets) {
            uint256 yield = currentAssets - previousAssets;
            totalYieldEarned += yield;
            
            // Calculate and take performance fee
            uint256 fee = (yield * performanceFeeBps) / FEE_DENOMINATOR;
            
            if (fee > 0) {
                // Transfer fee to recipient in underlying asset
                IERC20(asset()).transfer(feeRecipient, fee);
            }
            
            emit YieldHarvested(yield, fee);
        }
        
        _lastTotalAssets = currentAssets;
    }
    
    /// @notice Execute custom strategy logic (e.g., deposit to Aave, buy bonds, stake)
    /// @dev Can only be called by accounts with STRATEGIST_ROLE
    /// @param data Encoded strategy parameters (implementation specific)
    function executeStrategy(bytes calldata data) 
        external 
        onlyRole(STRATEGIST_ROLE) 
        whenNotPaused 
    {
        emit StrategyExecuted(data);
        // Strategy implementation would be customized here
        // Examples:
        // - Swap tokens via DEX
        // - Deposit to lending protocol
        // - Stake to validator
        // - Buy yield-bearing bonds
    }
    
    // ========== PUBLIC FUNCTIONS ==========
    
    /// @notice Total assets under management
    /// @dev Override to include any yield-bearing positions in strategies
    /// @return Total amount of underlying assets controlled by vault
    function totalAssets() public view override returns (uint256) {
        // Base implementation: just the underlying token balance
        // In a real strategy, this would also include:
        // - Tokens deposited in external protocols
        // - Pending rewards
        // - LP positions
        return IERC20(asset()).balanceOf(address(this));
    }
    
    /// @notice Deposit assets into vault with deadline protection
    /// @param assets Amount of underlying assets to deposit
    /// @param receiver Address that receives the shares
    /// @return shares Amount of shares minted
    function deposit(
        uint256 assets,
        address receiver
    ) public override nonReentrant whenNotPaused returns (uint256 shares) {
        require(assets > 0, "ForgeVault: cannot deposit 0");
        
        shares = super.deposit(assets, receiver);
        
        // Update tracking for yield calculation
        if (_lastTotalAssets == 0) {
            _lastTotalAssets = totalAssets();
        }
    }
    
    /// @notice Withdraw assets from vault with deadline protection
    /// @param assets Amount of underlying assets to withdraw
    /// @param receiver Address that receives the assets
    /// @param owner Address that owns the shares (must be msg.sender or approved)
    /// @return shares Amount of shares burned
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override nonReentrant whenNotPaused returns (uint256 shares) {
        require(assets > 0, "ForgeVault: cannot withdraw 0");
        shares = super.withdraw(assets, receiver, owner);
    }
    
    /// @notice Mint shares with deadline protection
    /// @param shares Amount of shares to mint
    /// @param receiver Address that receives the shares
    /// @return assets Amount of underlying assets deposited
    function mint(
        uint256 shares,
        address receiver
    ) public override nonReentrant whenNotPaused returns (uint256 assets) {
        require(shares > 0, "ForgeVault: cannot mint 0 shares");
        assets = super.mint(shares, receiver);
    }
    
    /// @notice Redeem shares with deadline protection
    /// @param shares Amount of shares to redeem
    /// @param receiver Address that receives the underlying assets
    /// @param owner Address that owns the shares
    /// @return assets Amount of underlying assets withdrawn
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override nonReentrant whenNotPaused returns (uint256 assets) {
        require(shares > 0, "ForgeVault: cannot redeem 0 shares");
        assets = super.redeem(shares, receiver, owner);
    }
    
    // ========== ADMIN FUNCTIONS ==========
    
    /// @notice Update performance fee percentage
    /// @dev Can only be called by DEFAULT_ADMIN_ROLE
    /// @param newFeeBps New fee in basis points (max 500 = 5%)
    function updatePerformanceFee(uint256 newFeeBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newFeeBps <= MAX_FEE_BPS, "ForgeVault: fee too high (max 5%)");
        emit FeeUpdated(performanceFeeBps, newFeeBps);
        performanceFeeBps = newFeeBps;
    }
    
    /// @notice Update fee recipient address
    /// @dev Can only be called by DEFAULT_ADMIN_ROLE
    /// @param newRecipient New address to receive performance fees
    function updateFeeRecipient(address newRecipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newRecipient != address(0), "ForgeVault: invalid address");
        emit FeeRecipientUpdated(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }
    
    /// @notice Pause all deposits and withdrawals (emergency only)
    /// @dev Can only be called by EMERGENCY_ROLE
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }
    
    /// @notice Unpause contract after emergency
    /// @dev Can only be called by DEFAULT_ADMIN_ROLE
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    // ========== OPTIONAL: SLIPPAGE PROTECTION ==========
    
    /// @notice Deposit with minimum shares received (slippage protection)
    /// @param assets Amount of underlying assets to deposit
    /// @param receiver Address that receives the shares
    /// @param minShares Minimum shares to accept
    /// @return shares Amount of shares minted
    function depositWithSlippage(
        uint256 assets,
        address receiver,
        uint256 minShares
    ) external returns (uint256 shares) {
        shares = deposit(assets, receiver);
        require(shares >= minShares, "ForgeVault: slippage too high");
    }
    
    /// @notice Withdraw with minimum assets received (slippage protection)
    /// @param assets Amount of underlying assets to withdraw
    /// @param receiver Address that receives the assets
    /// @param owner Address that owns the shares
    /// @param minShares Minimum shares to burn
    /// @return shares Amount of shares burned
    function withdrawWithSlippage(
        uint256 assets,
        address receiver,
        address owner,
        uint256 minShares
    ) external returns (uint256 shares) {
        shares = withdraw(assets, receiver, owner);
        require(shares <= minShares, "ForgeVault: slippage too high");
    }
    
    // ========== VIEW FUNCTIONS ==========
    
    /// @notice Get the current share price
    /// @return The value of 1 share in underlying assets
    function getSharePrice() external view returns (uint256) {
        uint256 totalSupply_ = totalSupply();
        if (totalSupply_ == 0) return 10 ** decimals();
        return (totalAssets() * (10 ** decimals())) / totalSupply_;
    }
    
    /// @notice Get the annualized yield (for display purposes)
    /// @dev Simple calculation based on total yield and time
    /// @return Estimated APY in basis points (e.g., 800 = 8%)
    function getEstimatedAPY() external view returns (uint256) {
        if (totalYieldEarned == 0) return 0;
        uint256 avgAssets = (totalAssets() + _lastTotalAssets) / 2;
        if (avgAssets == 0) return 0;
        
        // This is a simplified APY calculation
        // In production, you'd track timestamps for accurate APY
        return (totalYieldEarned * 10000) / avgAssets;
    }
}