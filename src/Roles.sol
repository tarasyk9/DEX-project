// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title Roles
/// @notice Defines role identifiers used for access control across the DEX contracts
library Roles {

    /// @notice Role assigned to protocol administrators
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role assigned to multisig administrators
    bytes32 public constant MULTISIG_ADMIN_ROLE = keccak256("MULTISIG_ADMIN_ROLE");

    /// @notice Role assigned to addresses allowed to execute EIP-712 swaps
    bytes32 public constant ALLOWED_EIP712_SWAP_ROLE = keccak256("ALLOWED_EIP712_SWAP_ROLE");
}
