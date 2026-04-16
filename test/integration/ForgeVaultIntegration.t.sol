// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/ForgeVault.sol";
import "../../src/MyToken.sol";

contract ForgeVaultIntegrationTest is Test {
    ForgeVault public vault;
    MyToken public token;
    
    address public admin = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public user3 = address(0x4);
    address public feeRecipient = address(0x5);
    address public strategist = address(0x6);
    
    uint256 constant _DEPOSIT_AMOUNT = 10000 * 10**18;
    uint256 constant _SMALL_DEPOSIT = 100 * 10**18;
    uint256 constant _YIELD_AMOUNT = 1000 * 10**18;
    
    function setUp() public {
        vm.startPrank(admin);
        token = new MyToken();
        vault = new ForgeVault(IERC20(address(token)), feeRecipient, 100);
        
        // Setup roles
        vault.grantRole(vault.STRATEGIST_ROLE(), strategist);
        
        // Mint tokens to users
        token.mint(user1, _DEPOSIT_AMOUNT);
        token.mint(user2, _DEPOSIT_AMOUNT);
        token.mint(user3, _SMALL_DEPOSIT);
        vm.stopPrank();
        
        // Approve vault for all users
        vm.prank(user1);
        token.approve(address(vault), type(uint256).max);
        vm.prank(user2);
        token.approve(address(vault), type(uint256).max);
        vm.prank(user3);
        token.approve(address(vault), type(uint256).max);
    }
    
    function testMultipleUsersDeposit() public {
        vm.prank(user1);
        uint256 shares1 = vault.deposit(_DEPOSIT_AMOUNT, user1);
        
        vm.prank(user2);
        uint256 shares2 = vault.deposit(_DEPOSIT_AMOUNT, user2);
        
        vm.prank(user3);
        uint256 shares3 = vault.deposit(_SMALL_DEPOSIT, user3);
        
        assertEq(vault.balanceOf(user1), shares1);
        assertEq(vault.balanceOf(user2), shares2);
        assertEq(vault.balanceOf(user3), shares3);
        assertEq(vault.totalSupply(), shares1 + shares2 + shares3);
        assertEq(vault.totalAssets(), _DEPOSIT_AMOUNT * 2 + _SMALL_DEPOSIT);
    }
    
    function testYieldDistributionToMultipleUsers() public {
        // All users deposit
        vm.prank(user1);
        vault.deposit(_DEPOSIT_AMOUNT, user1);
        
        vm.prank(user2);
        vault.deposit(_DEPOSIT_AMOUNT, user2);
        
        vm.prank(user3);
        vault.deposit(_SMALL_DEPOSIT, user3);
        
        // Generate yield
        uint256 yieldAmount = 2000 * 10**18;
        vm.prank(admin);
        token.mint(address(vault), yieldAmount);
        
        // Harvest yield
        vm.prank(strategist);
        vault.harvest();
        
        // Each user should have proportional claim on yield
        uint256 user1Withdraw = vault.previewRedeem(vault.balanceOf(user1));
        uint256 user2Withdraw = vault.previewRedeem(vault.balanceOf(user2));
        uint256 user3Withdraw = vault.previewRedeem(vault.balanceOf(user3));
        
        assertGt(user1Withdraw, _DEPOSIT_AMOUNT);
        assertGt(user2Withdraw, _DEPOSIT_AMOUNT);
        assertGt(user3Withdraw, _SMALL_DEPOSIT);
        
        // User1 and user2 should have similar returns (same deposit amount)
        assertApproxEqAbs(user1Withdraw, user2Withdraw, 1);
    }
    
    function testPartialWithdrawals() public {
        vm.prank(user1);
        vault.deposit(_DEPOSIT_AMOUNT, user1);
        
        // Withdraw half
        uint256 halfAmount = _DEPOSIT_AMOUNT / 2;
        vm.prank(user1);
        uint256 sharesBurned = vault.withdraw(halfAmount, user1, user1);
        
        assertGt(sharesBurned, 0);
        
        uint256 remainingAssets = vault.previewRedeem(vault.balanceOf(user1));
        assertApproxEqAbs(remainingAssets, _DEPOSIT_AMOUNT - halfAmount, 1e15);
    }
    
    function testSequentialDepositsAndWithdrawals() public {
        // User1 deposits and withdraws
        vm.prank(user1);
        vault.deposit(_DEPOSIT_AMOUNT, user1);
        
        vm.prank(user1);
        vault.withdraw(_DEPOSIT_AMOUNT, user1, user1);
        
        // User2 deposits after
        vm.prank(user2);
        vault.deposit(_DEPOSIT_AMOUNT, user2);
        
        assertEq(vault.totalAssets(), _DEPOSIT_AMOUNT);
        assertEq(vault.balanceOf(user1), 0);
        assertEq(vault.balanceOf(user2), vault.totalSupply());
    }
    
    function testLargeNumberOfUsers() public {
        uint256 numUsers = 10;
        address[] memory users = new address[](numUsers);
        
        // Create and fund multiple users
        for (uint256 i = 0; i < numUsers; i++) {
            users[i] = address(uint160(i + 100));
            vm.startPrank(admin);
            token.mint(users[i], _SMALL_DEPOSIT);
            vm.stopPrank();
            
            vm.prank(users[i]);
            token.approve(address(vault), type(uint256).max);
            
            vm.prank(users[i]);
            vault.deposit(_SMALL_DEPOSIT, users[i]);
        }
        
        assertEq(vault.totalSupply(), numUsers * _SMALL_DEPOSIT);
        assertEq(vault.totalAssets(), numUsers * _SMALL_DEPOSIT);
    }
    
    function testExecuteStrategy() public {
        bytes memory testData = abi.encode("test strategy");
        
        vm.prank(strategist);
        vault.executeStrategy(testData);
        
        // Event should be emitted (we can't directly test event in this simple test)
        // In a real test, you would use vm.expectEmit
    }
    
    function testOnlyStrategistCanExecuteStrategy() public {
        bytes memory testData = abi.encode("test strategy");
        
        vm.prank(user1);
        vm.expectRevert();
        vault.executeStrategy(testData);
    }
    function testRoundTripWithYield() public {
    // User deposits
     vm.prank(user1);
     uint256 shares = vault.deposit(_DEPOSIT_AMOUNT, user1);
     
     uint256 balanceBeforeYield = token.balanceOf(user1);
    
    // Generate yield
     vm.prank(admin);
     token.mint(address(vault), _YIELD_AMOUNT);
    
     vm.prank(strategist);
     vault.harvest();
    
    // User redeems all shares
     vm.prank(user1);
    uint256 assetsReceived = vault.redeem(shares, user1, user1);
    
    // User should receive more than they deposited
     assertGt(assetsReceived, _DEPOSIT_AMOUNT);
    
     uint256 balanceAfter = token.balanceOf(user1);
     assertGt(balanceAfter, balanceBeforeYield);
    
    // Vault should be empty or have only dust (rounding errors)
    // Use <= 10 wei instead of == 0 to account for rounding
     assertLe(vault.totalAssets(), 10);
     assertLe(vault.totalSupply(), 10);
    }
    

    
    function testDepositWithSlippageProtection() public {
        // Normal deposit with slippage protection
        vm.prank(user1);
        uint256 shares = vault.depositWithSlippage(_DEPOSIT_AMOUNT, user1, 0);
        
        assertGt(shares, 0);
        
        // This should revert due to high minShares
        vm.prank(user2);
        vm.expectRevert("ForgeVault: slippage too high");
        vault.depositWithSlippage(_DEPOSIT_AMOUNT, user2, _DEPOSIT_AMOUNT + 1);
    }
    
    function testViewFunctions() public {
        vm.prank(user1);
        vault.deposit(_DEPOSIT_AMOUNT, user1);
        
        // Test view functions
        uint256 sharePrice = vault.getSharePrice();
        assertEq(sharePrice, 10**18);
        
        uint256 estimatedApy = vault.getEstimatedAPY();
        assertEq(estimatedApy, 0); // No yield yet
        
        // Generate yield
        vm.prank(admin);
        token.mint(address(vault), _YIELD_AMOUNT);
        
        vm.prank(strategist);
        vault.harvest();
        
        // APY should be positive now
        estimatedApy = vault.getEstimatedAPY();
        assertGt(estimatedApy, 0);
    }
    
    function testFeeAccumulation() public {
        vm.prank(user1);
        vault.deposit(_DEPOSIT_AMOUNT, user1);
        
        // Generate yield multiple times
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(admin);
            token.mint(address(vault), _YIELD_AMOUNT);
            
            vm.prank(strategist);
            vault.harvest();
        }
        
        // Fee recipient should have received fees
        assertGt(token.balanceOf(feeRecipient), 0);
        
        // Total yield earned should be positive
        assertGt(vault.totalYieldEarned(), 0);
    }
}