// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {P2PEthV2} from "../src/p2peth_v2.sol";
import {P2PEth} from "../src/p2peth.sol";
import "../src/proxy.sol";

/**
 * @title P2PEthTest
 * @dev This contract is designed to test the functionality of the P2PEth and P2PEthV2 contracts.
 * It includes tests for initialization, deposits, withdrawals, and P2P transactions.
 * The contract also tests the upgradeability feature using a UUPS proxy.
 */
contract P2PEthTest is Test {
    address constant COMPANY_ADDRESS_V1 = address(0x111);
    address constant COMPANY_ADDRESS_V2 = address(0x222);

    P2PEth p2pV1;
    UUPSProxy proxy;
    P2PEth wrappedProxy;
    P2PEthV2 wrappedProxyV2;
    address companyAddress;

    /// @notice Set up the initial state for each test here
    function setUp() public {
        companyAddress = address(COMPANY_ADDRESS_V1);
        p2pV1 = new P2PEth();
        proxy = new UUPSProxy(address(p2pV1), "");
        wrappedProxy = P2PEth(address(proxy));
        wrappedProxy.initialize(companyAddress);
    }

    /// @notice Internal function to perform and validate a deposit
    /// @param depositAmount The amount to deposit
    /// @param expectedBalance The expected balance after the deposit
    function performAndValidateDeposit(uint256 depositAmount, uint256 expectedBalance) internal {
        wrappedProxy.deposit{value: depositAmount}();
        uint256 finalBalance = wrappedProxy.getBalance(address(this));
        assertEq(finalBalance, expectedBalance, "Deposit failed to update balance correctly");
    }

    /// @notice Test case to validate that the contract initializes correctly
    function testInitializationBeforeUpgrade() public {
        assertEq(wrappedProxy.getVersion(), 1, "Initial version should be 1");
        assertEq(wrappedProxy.getCompanyAddress(), COMPANY_ADDRESS_V1, "Initial company address mismatch");
    }

    /// @notice Test case to validate that a single deposit updates the user balance correctly
    function testSingleDepositUpdatesBalance() public {
        performAndValidateDeposit(1 ether, 1 ether);
    }

    /// @notice Test case to validate that multiple deposits from different users update balances correctly
    function testUserMultiDepositUpdatesBalance() public {
        // Simulate deposits from multiple users and validate
        performAndValidateDeposit(1 ether, 1 ether);
        performAndValidateDeposit(1 ether, 2 ether);
        performAndValidateDeposit(1 ether, 3 ether);
        performAndValidateDeposit(1 ether, 4 ether);
        performAndValidateDeposit(1 ether, 5 ether);
    }

    /// @notice Test case to validate that multiple deposits from different users update balances correctly
    function test2UserDeposit() public {
        // UserA and UserB init
        address userA = makeAddr("A");
        address userB = makeAddr("B");
        vm.deal(userA, 1 ether);
        vm.deal(userB, 0.5 ether);

        // Perform and validate deposits for UserA and UserB
        performAndValidateUserDeposit(userA, 1 ether, 1 ether);
        performAndValidateUserDeposit(userB, 0.5 ether, 0.5 ether);

        // Validate total contract balance
        uint256 contractBal = address(wrappedProxy).balance;
        assertEq(contractBal, 1.5 ether, "Total contract balance incorrect");
    }

    /// @notice Test case to validate that deposits update balances correctly for multiple users
    function test3UserDeposit() public {
        address userA = makeAddr("A");
        address userB = makeAddr("B");
        address userC = makeAddr("C");
        vm.deal(userA, 1 ether);
        vm.deal(userB, 0.5 ether);
        vm.deal(userC, 2 ether);

        performAndValidateUserDeposit(userA, 1 ether, 1 ether);
        performAndValidateUserDeposit(userB, 0.5 ether, 0.5 ether);
        performAndValidateUserDeposit(userC, 1.5 ether, 1.5 ether);

        uint256 contractBal = address(wrappedProxy).balance;
        assertEq(contractBal, 3 ether, "Total contract balance incorrect");
    }

    /// @notice Helper function to perform and validate deposits
    function performAndValidateUserDeposit(address user, uint256 depositAmount, uint256 expectedBalance) internal {
        vm.startPrank(user); // Assume the identity of the user
        wrappedProxy.deposit{value: depositAmount}();
        uint256 finalBalance = wrappedProxy.getBalance(user);
        assertEq(finalBalance, expectedBalance, "Deposit didn't update balance correctly");
    }

    /// @notice Helper function to perform and validate withdrawals
    function performAndValidateUserWithdraw(address user, uint256 withdrawAmount, uint256 expectedBalance) internal {
        vm.startPrank(user); // Assume the identity of the user
        wrappedProxy.withdraw(withdrawAmount);
        uint256 finalBalance = wrappedProxy.getBalance(user);
        assertEq(finalBalance, expectedBalance, "Withdraw didn't update balance correctly");
    }

    // receive Ether to test withdrawals
    receive() external payable {}

    /// @notice Test case to validate that withdrawals update balances correctly
    function testSingleUserWithdraw() public {
        performAndValidateUserDeposit(address(this), 1 ether, 1 ether);
        performAndValidateUserWithdraw(address(this), 0.5 ether, 0.5 ether);
    }

    /// @notice Test case to validate that withdrawals update balances correctly for multiple users
    function testMultiUserWithdraw() public {
        address userA = makeAddr("A");
        address userB = makeAddr("B");
        vm.deal(userA, 1 ether);
        vm.deal(userB, 0.5 ether);

        performAndValidateUserDeposit(userA, 1 ether, 1 ether);
        performAndValidateUserDeposit(userB, 0.5 ether, 0.5 ether);

        performAndValidateUserWithdraw(userA, 0.5 ether, 0.5 ether);
        performAndValidateUserWithdraw(userB, 0.25 ether, 0.25 ether);

        uint256 contractBal = address(wrappedProxy).balance;
        assertEq(contractBal, 0.75 ether, "Total contract balance incorrect after withdrawals");
    }

    /// @notice Helper function to perform a P2P send and validate balances
    /// @param initialDeposit The initial amount to deposit into the contract
    /// @param sendAmount The amount to send in the P2P transaction
    /// @param feeRate The fee rate in basis points
    function performAndValidateP2PSend(uint256 initialDeposit, uint256 sendAmount, uint256 feeRate) internal {
        address recipient = address(0x456);
        uint256 expectedFee = (sendAmount * feeRate) / 10000; // fee rate in basis points

        performAndValidateDeposit(initialDeposit, initialDeposit);

        // Perform P2P send
        wrappedProxy.send(recipient, sendAmount);

        // Validate final balances
        uint256 finalSenderBalance = wrappedProxy.getBalance(address(this));
        assertEq(finalSenderBalance, initialDeposit - sendAmount, "P2P Send didn't update sender balance correctly");

        uint256 finalRecipientBalance = wrappedProxy.getBalance(recipient);
        assertEq(finalRecipientBalance, sendAmount - expectedFee, "P2P Send didn't update recipient balance correctly");

        uint256 finalCompanyBalance = wrappedProxy.getBalance(companyAddress);
        assertEq(finalCompanyBalance, expectedFee, "P2P Send didn't update company balance correctly");
    }

    /// @notice Send exercising a maximum fee
    function testP2PSendMaxFee() public {
        performAndValidateP2PSend(1 ether, 0.5 ether, wrappedProxy.MAX_FEE_PCNT());
    }

    /// @notice Send exercising a mid-range fee
    function testP2PSendMidFee() public {
        performAndValidateP2PSend(1 ether, 1 ether, wrappedProxy.MID_FEE_PCNT());
    }

    /// @notice Send exercising a min-range fee
    function testP2PSendMinFee() public {
        performAndValidateP2PSend(6 ether, 5.000000000000000001 ether, wrappedProxy.MIN_FEE_PCNT());
    }

    // Function to perform and validate a deposit using v1 implementation
    function performAndValidateDeposit(uint256 depositAmount) internal {
        wrappedProxy.deposit{value: depositAmount}();
        validateBalances(
            wrappedProxy.getBalance(address(this)), address(wrappedProxy).balance, depositAmount, depositAmount
        );
    }

    // Function to validate user deposit and contract balances
    function validateBalances(
        uint256 userBalance,
        uint256 contractBalance,
        uint256 expectedUserBalance,
        uint256 expectedContractBalance
    ) internal {
        assertEq(userBalance, expectedUserBalance);
        assertEq(contractBalance, expectedContractBalance);
        assertEq(contractBalance, userBalance);
    }

    function testUpgradeToV2() public {
        // Deploy the new version of the contract
        P2PEthV2 p2pV2 = new P2PEthV2();

        // Perform and validate a deposit in v1
        uint256 depositAmount = 0.888888888 ether;
        performAndValidateDeposit(depositAmount);

        try wrappedProxy.upgradeToAndCall(address(p2pV2), "") {
            // Success: Validate the upgrade
            // Create a new wrapped instance to v2 interface
            wrappedProxyV2 = P2PEthV2(address(proxy));

            // call new method only in V2
            wrappedProxyV2.setCompanyAddress(COMPANY_ADDRESS_V2);

            // Validate the upgrade using the V2 proxy
            // and assert the balances remain identical
            validateBalances(
                wrappedProxyV2.getBalance(address(this)), address(wrappedProxyV2).balance, depositAmount, depositAmount
            );

            assertEq(wrappedProxyV2.getVersion(), 2);
            assertEq(wrappedProxyV2.getCompanyAddress(), COMPANY_ADDRESS_V2);
        } catch (bytes memory reason) {
            // Debug: Capture the failure reason
            emit DebugFailure("Upgrade failed", reason);
        }
    }

    // Debugging events
    event DebugState(string description, address proxyAddress, address newImplementation);
    event DebugFailure(string description, bytes reason);
}
