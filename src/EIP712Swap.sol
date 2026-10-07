// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./LiquidityPool.sol";
import "./ISwap.sol";

/// @title EIP-712 Swap Executor
/// @notice Allows users to authorize token swaps using EIP-712 typed-data signatures
contract EIP712Swap is EIP712 {
    using ECDSA for bytes32;

    /// @notice Stores the current nonce for each swap signer
    mapping(address => uint256) private _nonces;

    /// @notice EIP-712 type hash used when hashing SwapRequest structures
    bytes32 private constant SWAP_TYPEHASH = keccak256(
        "SwapRequest(address pool,address sender,address tokenIn,address tokenOut,uint256 amountIn,uint256 minAmountOut,uint256 nonce,uint256 deadline)"
    );

    /// @notice Thrown when the recovered signer does not match the request sender
    error InvalidSignature();

    /// @notice Thrown when a signed swap request has expired
    error ExpiredSwapRequest();

    /// @notice Thrown when the supplied nonce does not match the sender's current nonce
    error InvalidNonce();

    /// @notice Initializes the EIP-712 signing domain
    /// @dev Uses "EIP712Swap" as the domain name and "1" as the domain version
    constructor() EIP712("EIP712Swap", "1") {}

    /// @notice Gets the EIP-712 domain separator used by this contract
    /// @return The current EIP-712 domain separator
    function getDomainSeparator() public view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /// @notice Gets the current nonce for a sender
    /// @param _sender Address whose nonce should be retrieved
    /// @return Current nonce of the sender
    function getNonce(address _sender) public view returns (uint256) {
        return _nonces[_sender];
    }

    /// @notice Verifies an EIP-712 signature for a swap request
    /// @param _swapRequest Swap request that was signed by the user
    /// @param _signature EIP-712 signature associated with the request
    /// @return True if the recovered signer matches the request sender
    function verify(ISwap.SwapRequest memory _swapRequest, bytes memory _signature) public view returns (bool) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    SWAP_TYPEHASH,
                    _swapRequest.pool,
                    _swapRequest.sender,
                    _swapRequest.tokenIn,
                    _swapRequest.tokenOut,
                    _swapRequest.amountIn,
                    _swapRequest.minAmountOut,
                    _swapRequest.nonce,
                    _swapRequest.deadline
                )
            )
        );
        address signer = digest.recover(_signature);
        return signer == _swapRequest.sender;
    }

    /// @notice Executes a swap authorized by an EIP-712 signature
    /// @param _swapRequest Signed swap request containing pool and swap parameters
    /// @param _signature EIP-712 signature produced by the request sender
    /// @return True when the swap has been successfully executed
    function executeSwap(ISwap.SwapRequest memory _swapRequest, bytes memory _signature) public returns (bool) {
        if (!verify(_swapRequest, _signature)) revert InvalidSignature();
        if (_swapRequest.deadline < block.timestamp) {
            revert ExpiredSwapRequest();
        }
        if (_swapRequest.nonce != _nonces[_swapRequest.sender]) {
            revert InvalidNonce();
        }

        _nonces[_swapRequest.sender]++;
        LiquidityPool(_swapRequest.pool)
            .swap(
                _swapRequest.sender,
                _swapRequest.tokenIn,
                _swapRequest.tokenOut,
                _swapRequest.amountIn,
                _swapRequest.minAmountOut
            );

        return true;
    }
}
