// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title UUPSProxy
 * @dev This contract implements the ERC1967 proxy pattern with UUPS (Universal Upgradeable Proxy Standard) support, inheriting the functionality from OpenZeppelin's ERC1967Proxy.
 * The implementation contract address is stored in the ERC1967 admin slot of the proxy contract and can be upgraded using the upgradeTo() function.
 * The proxy contract forwards all function calls to the implementation contract using delegatecall, preserving the context (msg.sender and msg.value) of the original caller.
 * This enables upgrades of the implementation contract without affecting the proxy contract's address, thus ensuring that dependent contracts continue to function as expected.
 */
 contract UUPSProxy is ERC1967Proxy {
    constructor(address _implementation, bytes memory _data)
        ERC1967Proxy(_implementation, _data)
    {}
}