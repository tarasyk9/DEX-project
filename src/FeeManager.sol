// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./ISwap.sol";

/// @title Fee Manager
/// @notice Manages and calculates swap fees for the DEX
/// @dev Uses UUPS upgradeability and OpenZeppelin role-based access control
contract FeeManager is Initializable, AccessControlUpgradeable, UUPSUpgradeable {

    /// @notice Denominator used for basis point calculations
    /// @dev 10,000 represents 100%, therefore 100 represents 1%
    uint256 public constant FEE_DENOMINATOR = 10_000;

    /// @notice Current swap fee expressed in basis points
    uint256 public fee;

    /// @notice Thrown when a fee greater than 100% is provided
    error FeeGreaterThanDenominator();

    /// @notice Emitted when the swap fee is updated
    /// @param oldFee Previous fee in basis points
    /// @param newFee New fee in basis points
    event FeeUpdated(uint256 oldFee, uint256 newFee);

    /// @notice Disables initialization of the implementation contract
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the FeeManager contract through the proxy
    /// @dev Grants the DEFAULT_ADMIN_ROLE to the address performing initialization
    /// @param _fee Initial swap fee expressed in basis points
    function initialize(uint256 _fee) external initializer {
        if (_fee > FEE_DENOMINATOR) {
            revert FeeGreaterThanDenominator();
    }
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        fee = _fee;
    }

    /// @notice Authorizes an upgrade to a new implementation contract
    /// @dev Required by the UUPS upgrade pattern.
    /// @param newImplementation Address of the new implementation contract
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}

    /// @notice Updates the swap fee
    /// @param _fee New swap fee expressed in basis points
    function setFee(uint256 _fee)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_fee > FEE_DENOMINATOR) {
            revert FeeGreaterThanDenominator();
        }

        uint256 oldFee = fee;
        fee = _fee;

        emit FeeUpdated(oldFee, _fee);
    }

    /// @notice Calculates the absolute fee amount for a swap
    /// @param swapParams Swap parameters containing the input amount and current pool reserves
    /// @return feeAmount Fee amount denominated in the output token
    function getFee(ISwap.SwapParams memory swapParams)
        external
        view
        returns (uint256 feeAmount)
    {
        uint256 amountOut =
            (swapParams.amount0 * swapParams.reserveToken1)
                / (swapParams.reserveToken0 + swapParams.amount0);

        feeAmount = (amountOut * fee) / FEE_DENOMINATOR;
    }
}