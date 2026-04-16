// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/ForgeVault.sol";
import "../../src/MyToken.sol";

contract ForgeVaultYieldTest is Test {
    ForgeVault public vault;
    MyToken public token;
    
    address public admin = address(0x1);
    address public user = address(0x2);
    address public user2 = address(0x3);
    address public feeRecipient = address(0x4);
    address public strategist = address(0x5);
    
    uint256 constant _DEPOSIT_AMOUNT = 10000 * 10**18;
    uint256 constant _YIELD_AMOUNT = 1000 * 10**18;
    
    function setUp() public {
        vm.startPrank(admin);
        token = new MyToken();
        vault = new ForgeVault(IERC20(address(token)), feeRecipient, 100);
        
        // Grant strategist role
        vault.grantRole(vault.STRATEGIST_ROLE(), strategist);
        
        token.mint(user, _DEPOSIT_AMOUNT);
        token.mint(user2, _DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        vm.prank(user);
        token.approve(address(vault), type(uint256).max);
        vm.prank(user2);
        token.approve(address(vault), type(uint256).max);
    }
    
    function testYieldHarvest() public {
        vm.prank(user);
        vault.deposit(_DEPOSIT_AMOUNT, user);
        
        vm.prank(admin);
        token.mint(address(vault), _YIELD_AMOUNT);
        
        uint256 beforeHarvest = token.balanceOf(feeRecipient);
        
        vm.prank(strategist);
        vault.harvest();
        
        uint256 afterHarvest = token.balanceOf(feeRecipient);
        uint256 expectedFee = (_YIELD_AMOUNT * 100) / 10000;
        
        assertEq(afterHarvest - beforeHarvest, expectedFee);
        assertEq(vault.totalYieldEarned(), _YIELD_AMOUNT);
    }
    
    function testOnlyStrategistCanHarvest() public {
        vm.prank(user);
        vm.expectRevert();
        vault.harvest();
    }
    
    function testMultipleHarvests() public {
        vm.prank(user);
        vault.deposit(_DEPOSIT_AMOUNT, user);
        
        vm.prank(admin);
        token.mint(address(vault), _YIELD_AMOUNT);
        
        vm.prank(strategist);
        vault.harvest();
        
        vm.prank(admin);
        token.mint(address(vault), _YIELD_AMOUNT);
        
        vm.prank(strategist);
        vault.harvest();
        
        // Due to fee rounding, allow 1% tolerance
        uint256 expectedYield = _YIELD_AMOUNT * 2;
        uint256 actualYield = vault.totalYieldEarned();
        uint256 delta = expectedYield / 100; // 1% tolerance
        
        assertApproxEqAbs(actualYield, expectedYield, delta);
    }
    
    function testSharesIncreaseWithYield() public {
        vm.prank(user);
        uint256 sharesBefore = vault.deposit(_DEPOSIT_AMOUNT, user);
        
        uint256 sharePriceBefore = vault.getSharePrice();
        assertEq(sharePriceBefore, 10**18);
        
        vm.prank(admin);
        token.mint(address(vault), _YIELD_AMOUNT);
        
        vm.prank(strategist);
        vault.harvest();
        
        uint256 sharePriceAfter = vault.getSharePrice();
        assertGt(sharePriceAfter, 10**18);
        
        assertEq(vault.balanceOf(user), sharesBefore);
        assertGt(vault.previewRedeem(sharesBefore), _DEPOSIT_AMOUNT);
    }
    
    function testPerformanceFeeUpdate() public {
        vm.prank(admin);
        vault.updatePerformanceFee(200);
        assertEq(vault.performanceFeeBps(), 200);
    }
    
    function testCannotSetFeeAboveMax() public {
        vm.prank(admin);
        vm.expectRevert("ForgeVault: fee too high (max 5%)");
        vault.updatePerformanceFee(600);
    }
    
    function testUpdateFeeRecipient() public {
        address newRecipient = address(0x6);
        
        vm.prank(admin);
        vault.updateFeeRecipient(newRecipient);
        
        assertEq(vault.feeRecipient(), newRecipient);
    }
    
    function testCannotSetFeeRecipientToZero() public {
        vm.prank(admin);
        vm.expectRevert("ForgeVault: invalid address");
        vault.updateFeeRecipient(address(0));
    }
    
    function testHarvestWithNoYield() public {
        vm.prank(user);
        vault.deposit(_DEPOSIT_AMOUNT, user);
        
        uint256 beforeYield = vault.totalYieldEarned();
        
        vm.prank(strategist);
        vault.harvest();
        
        assertEq(vault.totalYieldEarned(), beforeYield);
    }
    
    function testYieldDoesntAffectEarlyWithdrawals() public {
        vm.prank(user);
        vault.deposit(_DEPOSIT_AMOUNT, user);
        
        vm.prank(user2);
        vault.deposit(_DEPOSIT_AMOUNT, user2);
        
        vm.prank(admin);
        token.mint(address(vault), _YIELD_AMOUNT);
        
        vm.prank(strategist);
        vault.harvest();
        
        uint256 user2Shares = vault.balanceOf(user2);
        uint256 user2WithdrawAmount = vault.previewRedeem(user2Shares);
        
        assertGt(user2WithdrawAmount, _DEPOSIT_AMOUNT);
        assertGt(vault.balanceOf(user), 0);
    }
    
    function testGetEstimatedAPY() public {
        vm.prank(user);
        vault.deposit(_DEPOSIT_AMOUNT, user);
        
        vm.prank(admin);
        token.mint(address(vault), _YIELD_AMOUNT);
        
        vm.prank(strategist);
        vault.harvest();
        
        uint256 apy = vault.getEstimatedAPY();
        assertGt(apy, 0);
    }
}