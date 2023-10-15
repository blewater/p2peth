
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract P2PEth is
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    // custom errors
    error Overflow(uint256 a, uint256 b);
    error Underflow(uint256 a, uint256 b);
    error ZeroAddress(address zeroAddress);
    error ZeroAmount(uint256 amount);
    error InsufficientBalance(uint256 balance, uint256 amount);
    error TransferFailed(address recipient, uint256 amount);

    // State variables
    mapping(address => uint256) private balances;
    address private companyAddress;

    // constants
    uint256 private constant Version = 1;
    uint256 private constant BASIS_POINTS = 10000; // For fee calculations
    uint256 public constant MAX_FEE_PCNT = 20; // 0.2%
    uint256 public constant MID_FEE_PCNT = 15; // 0.15%
    uint256 public constant MIN_FEE_PCNT = 10; // 0.1%

    // Events
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Sent(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 fee
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

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

    function getVersion() public pure returns (uint256) {
        return Version;
    }

    function getCompanyAddress() external view onlyOwner() returns (address) {
        return companyAddress;
    }

    // Deposit function. Because it's not interacting with external contracts, it's not marked as nonReentrant.
    // This assumption should be revisited whenever the deposit logic is modified.
    function deposit() external payable {
        if (msg.value == 0) {
            revert ZeroAmount(msg.value);
        }
        unchecked {
            uint256 newBalance = balances[msg.sender] + msg.value;
            if (newBalance < balances[msg.sender]) {
                revert Overflow(balances[msg.sender], msg.value);
            }
            balances[msg.sender] = newBalance;
        }

        emit Deposited(msg.sender, msg.value);
    }

    // Withdraw function
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

        bool success;
        assembly {
            let data := mload(0x40)  // Load the free memory pointer
            mstore(data, 0x0)        // Store a 0 length of the bytes array
            success := call(gas(), caller(), amount, add(data, 0x20), mload(data), 0, 0)
        }
        */
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert TransferFailed(msg.sender, amount);
        }

        emit Withdrawn(msg.sender, amount);
    }

    // Send function
    function send(address recipient, uint256 amount) external nonReentrant {
        if (balances[msg.sender] < amount) {
            revert InsufficientBalance(balances[msg.sender], amount);
        }
        if (recipient == address(0)) {
            revert ZeroAddress(recipient);
        }

        uint256 fee = calculateFee(amount);

        unchecked {
            // balances[msg.sender] - amount;
            uint256 newBalance = balances[msg.sender] - amount;
            if (newBalance > balances[msg.sender]) {
                revert Underflow(balances[msg.sender], amount);
            }
            balances[msg.sender] = newBalance;

            // amount - fee
            uint256 amountMinusFee = amount - fee;
            if (amountMinusFee > amount) {
                revert Underflow(amount, fee);
            }

            // balances[recipient] + amountMinusFee;
            newBalance = balances[recipient] + amountMinusFee;
            if (newBalance < balances[recipient]) {
                revert Overflow(balances[recipient], amountMinusFee);
            }
            balances[recipient] = newBalance;

            // balances[companyAddress] + fee;
            newBalance = balances[companyAddress] + fee;
            if (newBalance < balances[companyAddress]) {
                revert Overflow(balances[companyAddress], fee);
            }
            balances[companyAddress] = newBalance;
        }

        emit Sent(msg.sender, recipient, amount, fee);
    }

    // View balance function
    function getBalance(address user) external view returns (uint256) {
        return balances[user];
    }

    // Internal function to calculate fee
    function calculateFee(uint256 amount) internal pure returns (uint256) {
        uint256 feeRate;
        if (amount < 1 ether) {
            feeRate = MAX_FEE_PCNT; // 0.2%
        } else if (amount <= 5 ether) {
            feeRate = MID_FEE_PCNT; // 0.15%
        } else {
            feeRate = MIN_FEE_PCNT; // 0.1%
        }

        // (amount * feeRate) / BASIS_POINTS
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

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
