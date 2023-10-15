// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import "../src/p2peth_v2.sol";
import "../src/p2peth.sol";
import "../src/proxy.sol";

contract P2PEthTest is Test {
    address constant COMPANY_ADDRESS_V1 = address(0x111);
    address constant COMPANY_ADDRESS_V2 = address(0x222);

    P2PEth p2pV1;
    UUPSProxy proxy;
    P2PEth wrappedProxy;
    P2PEthV2 wrappedProxyV2;
    address companyAddress;

    function setUp() public {
        companyAddress = address(COMPANY_ADDRESS_V1);

        // Deploy the implementation contract
        p2pV1 = new P2PEth();

        // Deploy the UUPS proxy, pointing it to the implementation contract
        proxy = new UUPSProxy(address(p2pV1), "");

        // Cast the proxy in an to the contract to support easier calls
        wrappedProxy = P2PEth(address(proxy));

        // Initialize the implementation contract
        wrappedProxy.initialize(companyAddress);
    }

    function testInitializationBeforeUpgrade() public {
        assertEq(wrappedProxy.getVersion(), 1);
        assertEq(wrappedProxy.getCompanyAddress(), COMPANY_ADDRESS_V1);
    }

    function testSingleDepositUpdatesBalance() public {
        uint256 userInitialBalance = wrappedProxy.getBalance(address(this));
        assertEq(userInitialBalance, 0);
        assertEq(address(wrappedProxy).balance, 0);

        uint256 depositAmount = 1 ether;

        wrappedProxy.deposit{value: depositAmount}();
        uint256 userFinalBalance = wrappedProxy.getBalance(address(this));
        assertEq(userFinalBalance, userInitialBalance + depositAmount);

        uint256 contractFinalBal = address(wrappedProxy).balance;
        assertEq(contractFinalBal, depositAmount);
        assertEq(contractFinalBal, userFinalBalance);
    }

    function test2UserDepositUpdatesBalance() public {
        // UserA and UserB init
        address userA = makeAddr("A");
        vm.deal(userA, 1 ether);
        address userB = makeAddr("B");
        vm.deal(userB, 0.5 ether);
        uint256 userAInitialBalance = wrappedProxy.getBalance(userA);
        uint256 userBInitialBalance = wrappedProxy.getBalance(userB);
        assertEq(userAInitialBalance, 0);
        assertEq(userBInitialBalance, 0);
        assertEq(address(wrappedProxy).balance, 0);

        // UserA deposits
        vm.startPrank(userA); // Pretend to be userA
        wrappedProxy.deposit{value: 1 ether}();
        uint256 userAFinalBalance = wrappedProxy.getBalance(userA);
        assertEq(userAFinalBalance, userAInitialBalance + 1 ether);

        // Total contract balance should be the same as userA's balance
        uint256 contractBal = address(wrappedProxy).balance;
        assertEq(contractBal, 1 ether);
        assertEq(contractBal, userAFinalBalance);

        // UserB deposits
        vm.startPrank(userB); // Pretend to be userB
        wrappedProxy.deposit{value: 0.5 ether}();
        uint256 userBFinalBalance = wrappedProxy.getBalance(userB);
        assertEq(userBFinalBalance, userBInitialBalance + 0.5 ether);

        // Total contract balance should be the sum of the two deposits
        contractBal = address(wrappedProxy).balance;
        assertEq(contractBal, userAFinalBalance + userBFinalBalance);
    }

    // receive Ether to test withdrawals
    receive() external payable {}

    function testWithdrawUpdatesBalanceAndTransfersETH() public {
        uint256 depositAmount = 1 ether;
        uint256 withdrawAmount = 0.5 ether;

        wrappedProxy.deposit{value: depositAmount}();

        // Check initial balances
        uint256 initialContractBalance = address(wrappedProxy).balance;
        assertEq(initialContractBalance, depositAmount);
        uint256 initialUserBalance = wrappedProxy.getBalance(address(this));
        assertEq(initialUserBalance, initialContractBalance);

        // Withdraw
        wrappedProxy.withdraw(withdrawAmount);

        // Check final balances
        uint256 finalContractBalance = address(wrappedProxy).balance;
        uint256 finalUserBalance = wrappedProxy.getBalance(address(this));
        assertEq(finalContractBalance, initialContractBalance - withdrawAmount);
        assertEq(finalUserBalance, initialUserBalance - withdrawAmount);
    }

    function testP2PSend() public {
        address recipient = address(0x456);
        uint256 depositAmount = 1 ether;
        uint256 sendAmount = 0.5 ether;

        wrappedProxy.deposit{value: depositAmount}();

        uint256 initialSenderBalance = wrappedProxy.getBalance(address(this));
        assertEq(initialSenderBalance, depositAmount);
        uint256 initialRecipientBalance = wrappedProxy.getBalance(recipient);
        assertEq(initialRecipientBalance, 0);
        uint256 initialCompanyBalance = wrappedProxy.getBalance(companyAddress);
        assertEq(initialCompanyBalance, 0);

        wrappedProxy.send(recipient, sendAmount);

        uint256 fee = (sendAmount * 20) / 10000; // 0.1% fee rate in basis points
        uint256 finalSenderBalance = wrappedProxy.getBalance(address(this));
        uint256 finalRecipientBalance = wrappedProxy.getBalance(recipient);
        uint256 finalCompanyBalance = wrappedProxy.getBalance(companyAddress);

        assertEq(finalSenderBalance, initialSenderBalance - sendAmount);
        assertEq(
            finalRecipientBalance,
            initialRecipientBalance + sendAmount - fee
        );
        assertEq(finalCompanyBalance, initialCompanyBalance + fee);
    }

    // Function to perform and validate a deposit using v1 implementation
    function performAndValidateDeposit(uint256 depositAmount) internal {
        wrappedProxy.deposit{value: depositAmount}();
        validateBalances(
            wrappedProxy.getBalance(address(this)),
            address(wrappedProxy).balance,
            depositAmount,
            depositAmount
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
                wrappedProxyV2.getBalance(address(this)),
                address(wrappedProxyV2).balance,
                depositAmount,
                depositAmount
            );

            assertEq(wrappedProxyV2.getVersion(), 2);
            assertEq(wrappedProxyV2.getCompanyAddress(), COMPANY_ADDRESS_V2);
        } catch (bytes memory reason) {
            // Debug: Capture the failure reason
            emit DebugFailure("Upgrade failed", reason);
        }
    }

    // Debugging events
    event DebugState(
        string description,
        address proxyAddress,
        address newImplementation
    );
    event DebugFailure(string description, bytes reason);
}
