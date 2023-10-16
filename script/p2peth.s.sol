// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {P2PEthV2} from "../src/p2peth_v2.sol";
import "../src/p2peth.sol";
import "../src/proxy.sol";

contract P2pEthScript is Script {
    address constant COMPANY_ADDRESS_V1 = address(0x111);
    address constant COMPANY_ADDRESS_V2 = address(0x222);

    P2PEth p2pV1;
    UUPSProxy proxy;
    P2PEth wrappedProxy;
    P2PEthV2 wrappedProxyV2;

    /// @notice Set up the initial state for each test here
    function setUp() public {
    }

    function run() public {
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        // Anvil account 0
        vm.startBroadcast(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);
        p2pV1 = new P2PEth();
        bytes memory data = abi.encodeWithSignature("initialize(address)", COMPANY_ADDRESS_V1);
        proxy = new UUPSProxy(address(p2pV1), data);
        wrappedProxy = P2PEth(address(proxy));
        vm.stopBroadcast(); 
    }
}