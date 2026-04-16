// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/ForgeVault.sol";
import "../../src/MyToken.sol";

contract ForgeVaultCoreTest is Test {
    ForgeVault public vault;
    MyToken public token;
    
    address public admin = address(0x1);
    address public user = address(0x2);
    address public feeRecipient = address(0x3);
    address public strategist = address(0x4);
    address public emergency = address(0x5);
    
    uint256 constant INITIAL_MINT = 10000 * 10**18;
    uint256 constant DEPOSIT_AMOUNT = 1000 * 10**18;
    
    function setUp() public {
        // Deploy token
        vm.startPrank(admin);
        token = new MyToken();
        
        // Deploy vault
        vault = new ForgeVault(
            IERC20(address(token)),
            feeRecipient,
            100 // 1% fee
        );
        
        // Setup roles
        vault.grantRole(vault.STRATEGIST_ROLE(), strategist);
        vault.grantRole(vault.EMERGENCY_ROLE(), emergency);
        
        // Mint tokens to user
        token.mint(user, INITIAL_MINT);
        vm.stopPrank();
        
        // Approve vault to spend user tokens
        vm.prank(user);
        token.approve(address(vault), type(uint256).max);
    }
    
    function testInitialState() public view {
        assertEq(vault.name(), "Forge Vault Token");
        assertEq(vault.symbol(), "fvToken");
        assertEq(vault.decimals(), 18);
        assertEq(vault.performanceFeeBps(), 100);
        assertEq(vault.feeRecipient(), feeRecipient);
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.getSharePrice(), 10**18);
    }
    
    function testDeposit() public {
        vm.prank(user);
        uint256 shares = vault.deposit(DEPOSIT_AMOUNT, user);
        
        // Check balances
        assertEq(vault.balanceOf(user), shares);
        assertEq(token.balanceOf(user), INITIAL_MINT - DEPOSIT_AMOUNT);
        assertEq(token.balanceOf(address(vault)), DEPOSIT_AMOUNT);
        assertEq(vault.totalAssets(), DEPOSIT_AMOUNT);
    }
    
    function testDepositZeroReverts() public {
        vm.prank(user);
        vm.expectRevert("ForgeVault: cannot deposit 0");
        vault.deposit(0, user);
    }
    
    function testWithdraw() public {
        // First deposit
        vm.prank(user);
        uint256 shares = vault.deposit(DEPOSIT_AMOUNT, user);
        
        // Then withdraw
        vm.prank(user);
        uint256 assets = vault.withdraw(DEPOSIT_AMOUNT, user, user);
        
        assertEq(assets, DEPOSIT_AMOUNT);
        assertEq(token.balanceOf(user), INITIAL_MINT);
        assertEq(vault.balanceOf(user), 0);
    }
    
    function testWithdrawZeroReverts() public {
        vm.prank(user);
        vm.expectRevert("ForgeVault: cannot withdraw 0");
        vault.withdraw(0, user, user);
    }
    
    function testCannotWithdrawMoreThanDeposited() public {
        vm.prank(user);
        vault.deposit(DEPOSIT_AMOUNT, user);
        
        vm.prank(user);
        vm.expectRevert();
        vault.withdraw(DEPOSIT_AMOUNT + 1, user, user);
    }
    
    function testSharePriceStartsAtOne() public {
        assertEq(vault.convertToAssets(1e18), 1e18);
        assertEq(vault.convertToShares(1e18), 1e18);
    }
    
    function testDepositMintConsistency() public {
        vm.prank(user);
        uint256 sharesDeposited = vault.deposit(DEPOSIT_AMOUNT, user);
        
        vm.prank(user);
        uint256 sharesMinted = vault.mint(sharesDeposited, user);
        
        assertEq(sharesDeposited, sharesMinted);
    }
    
    function testMintZeroReverts() public {
        vm.prank(user);
        vm.expectRevert("ForgeVault: cannot mint 0 shares");
        vault.mint(0, user);
    }
    
    function testRedeemZeroReverts() public {
        vm.prank(user);
        vm.expectRevert("ForgeVault: cannot redeem 0 shares");
        vault.redeem(0, user, user);
    }
    
    function testMultipleDeposits() public {
        vm.prank(user);
        vault.deposit(DEPOSIT_AMOUNT, user);
        
        vm.prank(user);
        vault.deposit(DEPOSIT_AMOUNT, user);
        
        assertEq(token.balanceOf(address(vault)), DEPOSIT_AMOUNT * 2);
        assertEq(vault.totalAssets(), DEPOSIT_AMOUNT * 2);
    }
    
    function testDepositToDifferentReceiver() public {
        address receiver = address(0x6);
        
        vm.prank(user);
        uint256 shares = vault.deposit(DEPOSIT_AMOUNT, receiver);
        
        assertEq(vault.balanceOf(user), 0);
        assertEq(vault.balanceOf(receiver), shares);
        assertEq(token.balanceOf(user), INITIAL_MINT - DEPOSIT_AMOUNT);
    }
    
    function testWithdrawFromDifferentOwner() public {
        address owner = user;
        address spender = address(0x7);
        
        // Deposit as owner
        vm.prank(owner);
        uint256 shares = vault.deposit(DEPOSIT_AMOUNT, owner);
        
        // Approve spender
        vm.prank(owner);
        vault.approve(spender, shares);
        
        // Withdraw as spender
        vm.prank(spender);
        uint256 assets = vault.withdraw(DEPOSIT_AMOUNT, spender, owner);
        
        assertEq(assets, DEPOSIT_AMOUNT);
        assertEq(token.balanceOf(spender), DEPOSIT_AMOUNT);
    }
    
    function testSlippageProtectionDeposit() public {
        vm.prank(user);
        uint256 shares = vault.depositWithSlippage(DEPOSIT_AMOUNT, user, 0);
        
        assertGt(shares, 0);
    }
    
    function testSlippageProtectionDepositReverts() public {
        vm.prank(user);
        vm.expectRevert("ForgeVault: slippage too high");
        vault.depositWithSlippage(DEPOSIT_AMOUNT, user, DEPOSIT_AMOUNT + 1);
    }
    
    function testPauseAndUnpause() public {
        // Emergency role can pause
        vm.prank(emergency);
        vault.pause();
        
        // Deposits should revert when paused
        vm.prank(user);
        vm.expectRevert("Pausable: paused");
        vault.deposit(DEPOSIT_AMOUNT, user);
        
        // Admin can unpause
        vm.prank(admin);
        vault.unpause();
        
        // Deposit should work again
        vm.prank(user);
        vault.deposit(DEPOSIT_AMOUNT, user);
        assertEq(vault.totalAssets(), DEPOSIT_AMOUNT);
    }
    
    function testOnlyEmergencyCanPause() public {
        vm.prank(user);
        vm.expectRevert();
        vault.pause();
    }
    
    function testOnlyAdminCanUnpause() public {
        vm.prank(emergency);
        vault.pause();
        
        vm.prank(user);
        vm.expectRevert();
        vault.unpause();
    }
}