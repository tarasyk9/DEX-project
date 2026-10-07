// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Roles.sol";

/// @title Access Manager
/// @notice Role management contract for the DEX protocol
/// @dev Uses OpenZeppelin AccessControl to manage administrator,
/// multisig administrator, and EIP-712 swapper roles.
contract AccessManager is AccessControl {
    using Roles for bytes32;

    /// @notice Initializes the access manager
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        _setRoleAdmin(Roles.ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(Roles.MULTISIG_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(Roles.ALLOWED_EIP712_SWAP_ROLE, DEFAULT_ADMIN_ROLE);
    }

    /// @notice Grants the protocol administrator role to an account
    /// @param _admin Address that will receive the administrator role
    function addAdmin(address _admin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(Roles.ADMIN_ROLE, _admin);
    }

    /// @notice Revokes the protocol administrator role from an account
    /// @param _admin Address from which the administrator role will be revoked
    function removeAdmin(address _admin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(Roles.ADMIN_ROLE, _admin);
    }

    /// @notice Grants the multisig administrator role to an account
    /// @param _multisigAdmin Address that will receive the multisig administrator role
    function addMultisigAdmin(address _multisigAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(Roles.MULTISIG_ADMIN_ROLE, _multisigAdmin);
    }

    /// @notice Revokes the multisig administrator role from an account
    /// @param _multisigAdmin Address from which the multisig administrator role will be revoked
    function removeMultisigAdmin(address _multisigAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(Roles.MULTISIG_ADMIN_ROLE, _multisigAdmin);
    }

    /// @notice Grants permission to execute EIP-712 based swaps
    /// @param _swapper Address that will receive the EIP-712 swap role
    function addEIP712Swapper(address _swapper) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(Roles.ALLOWED_EIP712_SWAP_ROLE, _swapper);
    }

    /// @notice Revokes permission to execute EIP-712 based swaps
    /// @param _swapper Address from which the EIP-712 swap role will be revoked
    function removeEIP712Swapper(address _swapper) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(Roles.ALLOWED_EIP712_SWAP_ROLE, _swapper);
    }

    /// @notice Checks whether an account has the administrator role
    /// @param _address Address to check
    /// @return True if the address has ADMIN_ROLE
    function isAdmin(address _address) external view returns (bool) {
        return hasRole(Roles.ADMIN_ROLE, _address);
    }

    /// @notice Checks whether an account has the multisig administrator role
    /// @param _address Address to check
    /// @return True if the address has MULTISIG_ADMIN_ROLE
    function isMultisigAdmin(address _address) external view returns (bool) {
        return hasRole(Roles.MULTISIG_ADMIN_ROLE, _address);
    }

    /// @notice Checks whether an account can execute EIP-712 swaps
    /// @param _address Address to check
    /// @return True if the address has ALLOWED_EIP712_SWAP_ROLE
    function isEIP712Swapper(address _address) external view returns (bool) {
        return hasRole(Roles.ALLOWED_EIP712_SWAP_ROLE, _address);
    }
}
