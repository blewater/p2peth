// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title P2PEth: A peer-to-peer Ether transfer contract with fees.
/// @notice This contract enables peer-to-peer Ether transfers with a fee mechanism.
/// @dev The contract uses OpenZeppelin's upgradeable contracts for better maintainability.
contract P2PEth is
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    /// Custom errors to provide more descriptive revert reasons.
    error Overflow(uint256 a, uint256 b);
    error Underflow(uint256 a, uint256 b);
    error ZeroAddress(address zeroAddress);
    error ZeroAmount(uint256 amount);
    error InsufficientBalance(uint256 balance, uint256 amount);
    error TransferFailed(address recipient, uint256 amount);

    /// @dev Mapping to store the Ether balance of each user.
    mapping(address => uint256) private balances;

    /// @dev Address where the fees will be sent.
    address private companyAddress;

    /// @dev Version of the contract, for tracking upgrades.
    uint256 private constant Version = 1;

    /// @dev Basis points for fee calculations.
    uint256 private constant BASIS_POINTS = 10000;

    /// @dev Maximum fee rate in basis points (0.2%).
    uint256 public constant MAX_FEE_PCNT = 20;

    /// @dev Medium fee rate in basis points (0.15%).
    uint256 public constant MID_FEE_PCNT = 15;

    /// @dev Minimum fee rate in basis points (0.1%).
    uint256 public constant MIN_FEE_PCNT = 10;

    /// Events to log significant contract state changes.
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Sent(address indexed from, address indexed to, uint256 amount, uint256 fee);

    /// @notice Contract constructor disabled due to the use of OpenZeppelin's Initializable.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract state.
    /// @param _companyAddress The address where fees will be sent.
    /// @dev This function can only be called once.
    function initialize(address _companyAddress) public initializer {
        __Pausable_init();
        __ReentrancyGuard_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        if (_companyAddress == address(0)) {
            revert ZeroAddress(_companyAddress);
        }
        companyAddress = _companyAddress;
    }

    /// @notice Fetches the contract version.
    /// @return The version of the contract.
    function getVersion() public pure returns (uint256) {
        return Version;
    }

    /// @notice Fetches the company address where fees are sent.
    /// @return The company address.
    /// @dev Only the contract owner can call this function.
    function getCompanyAddress() external view onlyOwner returns (address) {
        return companyAddress;
    }

    /// @notice Allows a user to deposit Ether into the contract.
    /// @dev Emits a Deposited event upon successful deposit.
    function deposit() external payable {
        if (msg.value == 0) {
            revert ZeroAmount(msg.value);
        }

        // bypass Sol's 0.8.x overflow checks to raise specific errors
        unchecked {
            uint256 newBalance = balances[msg.sender] + msg.value;
            if (newBalance < balances[msg.sender]) {
                revert Overflow(balances[msg.sender], msg.value);
            }
            balances[msg.sender] = newBalance;
        }

        emit Deposited(msg.sender, msg.value);
    }

    /// @notice Allows a user to withdraw Ether from the contract.
    /// @param amount The amount of Ether to withdraw.
    /// @dev Emits a Withdrawn event upon successful withdrawal.
    function withdraw(uint256 amount) external nonReentrant {
        if (balances[msg.sender] < amount) {
            revert InsufficientBalance(balances[msg.sender], amount);
        }
        if (address(this).balance < amount) {
            revert InsufficientBalance(address(this).balance, amount);
        }

        unchecked {
            uint256 newBalance = balances[msg.sender] - amount;
            if (newBalance > balances[msg.sender]) {
                revert Underflow(balances[msg.sender], amount);
            }
            balances[msg.sender] = newBalance;
        }

        /**
         * Minimal gas savings in assembly version: max 36661 vs 37069 (Solidity)
         * Left here only for reference
         *
         *     bool success;
         *     assembly {
         *         let data := mload(0x40)  // Load the free memory pointer
         *         mstore(data, 0x0)        // Store a 0 length of the bytes array
         *         success := call(gas(), caller(), amount, add(data, 0x20), mload(data), 0, 0)
         *     }
         */
        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert TransferFailed(msg.sender, amount);
        }

        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Allows a user to send Ether to another user.
    /// @param recipient The address of the recipient.
    /// @param amount The amount of Ether to send.
    /// @dev Emits a Sent event upon successful transfer.
    function send(address recipient, uint256 amount) external nonReentrant {
        if (balances[msg.sender] < amount) {
            revert InsufficientBalance(balances[msg.sender], amount);
        }
        if (recipient == address(0)) {
            revert ZeroAddress(recipient);
        }

        uint256 fee = calculateFee(amount);

        unchecked {
            uint256 newBalance = balances[msg.sender] - amount;
            if (newBalance > balances[msg.sender]) {
                revert Underflow(balances[msg.sender], amount);
            }
            balances[msg.sender] = newBalance;

            uint256 amountMinusFee = amount - fee;
            if (amountMinusFee > amount) {
                revert Underflow(amount, fee);
            }

            newBalance = balances[recipient] + amountMinusFee;
            if (newBalance < balances[recipient]) {
                revert Overflow(balances[recipient], amountMinusFee);
            }
            balances[recipient] = newBalance;

            newBalance = balances[companyAddress] + fee;
            if (newBalance < balances[companyAddress]) {
                revert Overflow(balances[companyAddress], fee);
            }
            balances[companyAddress] = newBalance;
        }

        emit Sent(msg.sender, recipient, amount, fee);
    }

    /// @notice Fetches the balance of a given user.
    /// @param user The address of the user.
    /// @return The Ether balance of the user.
    function getBalance(address user) external view returns (uint256) {
        return balances[user];
    }

    /// @notice Calculates the fee for a given amount.
    /// @param amount The amount for which the fee needs to be calculated.
    /// @return The calculated fee.
    /// @dev The fee rate is determined based on the amount.
    function calculateFee(uint256 amount) internal pure returns (uint256) {
        uint256 feeRate;
        if (amount < 1 ether) {
            feeRate = MAX_FEE_PCNT;
        } else if (amount <= 5 ether) {
            feeRate = MID_FEE_PCNT;
        } else {
            feeRate = MIN_FEE_PCNT;
        }

        unchecked {
            uint256 amountTimesFeeRate = amount * feeRate;
            if (amountTimesFeeRate < amount) {
                revert Underflow(amount, feeRate);
            }

            uint256 fee = amountTimesFeeRate / BASIS_POINTS;
            if (fee > amount) {
                revert Overflow(amountTimesFeeRate, BASIS_POINTS);
            }

            return fee;
        }
    }

    /// @notice Authorizes an upgrade to a new contract implementation.
    /// @param newImplementation The address of the new contract implementation.
    /// @dev Only the contract owner can authorize an upgrade.
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @notice Pauses the contract, disabling all state-changing functions.
    /// @dev Only the contract owner can pause the contract.
    function pause() public onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract, enabling all state-changing functions.
    /// @dev Only the contract owner can unpause the contract.
    function unpause() public onlyOwner {
        _unpause();
    }
}
