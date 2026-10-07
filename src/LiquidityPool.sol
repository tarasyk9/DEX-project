// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./ISwap.sol";
import "./FeeManager.sol";
import "./EIP712Swap.sol";
import "./Roles.sol";

/// @title Liquidity Pool
/// @notice Manages liquidity and executes token swaps for a two-token DEX pool
contract LiquidityPool is ISwap, AccessControl, ReentrancyGuard {
    using Roles for bytes32;

    /// @notice Address of the first token in the pool
    address public token0;

    /// @notice Number of decimals used by token0
    uint256 public token0Decimals;

    /// @notice Address of the second token in the pool
    address public token1;

    /// @notice Number of decimals used by token1
    uint256 public token1Decimals;

    /// @notice Current tracked reserve of token0
    uint256 public reserveToken0;

    /// @notice Current tracked reserve of token1
    uint256 public reserveToken1;

    /// @notice Fee manager used to calculate swap fees
    FeeManager public feeManager;

    /// @notice EIP-712 swap executor associated with this pool
    EIP712Swap public eip712Swap;

    /// @notice Restricts swap execution to administrators or authorized EIP-712 executors
    modifier onlyAdminOrEIP712Swap() {
        require(
            hasRole(Roles.ADMIN_ROLE, msg.sender) || hasRole(Roles.ALLOWED_EIP712_SWAP_ROLE, msg.sender),
            UnauthorizedSwapCaller(msg.sender)
        );
        _;
    }

    /// @notice Emitted when liquidity is added to the pool
    /// @param _token Address of the deposited token
    /// @param _amount Amount of tokens deposited
    event LiquidityAdded(
        address indexed _token,
        uint256 _amount
    );

    /// @notice Emitted after a successful token swap
    /// @param _tokenIn Address of the input token
    /// @param _tokenOut Address of the output token
    /// @param _amountIn Amount of input tokens supplied
    /// @param _amountOut Amount of output tokens received
    event Swap(
        address indexed _tokenIn,
        address indexed _tokenOut,
        uint256 _amountIn,
        uint256 _amountOut
    );

    /// @notice Thrown when pool does not have enough tokens
    error InsufficientReserves();

    /// @notice Thrown when an account does not have enough tokens
    error InsufficientTokenBalance();

    /// @notice Thrown when an unauthorized address attempts to execute a swap
    /// @param caller Address that attempted to execute the swap
    error UnauthorizedSwapCaller(address caller);

    /// @notice Thrown when a token does not belong to this liquidity pool
    /// @param _token Invalid token address
    error InvalidTokenAddress(address _token);

    /// @notice Thrown when an invalid input/output token pair is supplied
    /// @param _tokenIn Requested input token
    /// @param _tokenOut Requested output token
    error InvalidTokenPair(address _tokenIn, address _tokenOut);

    /// @notice Thrown when the pool does not contain sufficient liquidity for a swap
    error InsufficientLiquidity();

    /// @notice Thrown when calculated output is below the user's minimum acceptable amount
    /// @param expected Minimum output amount requested by the user
    /// @param actual Actual output amount calculated by the pool
    error InsufficientOutputAmount(
        uint256 expected,
        uint256 actual
    );

    /// @notice Thrown when the pool does not have sufficient token allowance
    error InsufficientAllowance();

    /// @notice Initializes a two-token liquidity pool
    /// @param _token0 Address of the first ERC-20 token
    /// @param _token0Decimals Number of decimals used by token0
    /// @param _token1 Address of the second ERC-20 token
    /// @param _token1Decimals Number of decimals used by token1
    /// @param _feeManager Address of the FeeManager contract
    /// @param _eip712Swap Address of the authorized EIP712Swap contract
    constructor(
        address _token0,
        uint256 _token0Decimals,
        address _token1,
        uint256 _token1Decimals,
        address _feeManager,
        address _eip712Swap
    ) {
        token0 = _token0;
        token0Decimals = _token0Decimals;

        token1 = _token1;
        token1Decimals = _token1Decimals;

        feeManager = FeeManager(_feeManager);
        eip712Swap = EIP712Swap(_eip712Swap);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(Roles.ADMIN_ROLE, msg.sender);

        _grantRole(
            Roles.ALLOWED_EIP712_SWAP_ROLE,
            _eip712Swap
        );

        // Configure role hierarchy.
        _setRoleAdmin(
            Roles.ADMIN_ROLE,
            DEFAULT_ADMIN_ROLE
        );

        _setRoleAdmin(
            Roles.ALLOWED_EIP712_SWAP_ROLE,
            DEFAULT_ADMIN_ROLE
        );
    }

    /// @notice Add liquidity to the pool (admin only)
    /// @param _token Address of the token to deposit
    /// @param _amount Amount of tokens to deposit
    function addLiquidity(address _token, uint256 _amount) external onlyRole(Roles.ADMIN_ROLE) {
        if (_token != token0 && _token != token1) {
            revert InvalidTokenAddress(_token);
        }

        if (IERC20(_token).balanceOf(msg.sender) < _amount) {
            revert InsufficientTokenBalance();
        }

        require(IERC20(_token).transferFrom(msg.sender, address(this), _amount));

        if (_token == token0) {
            reserveToken0 += _amount;
        } else {
            reserveToken1 += _amount;
        }

        emit LiquidityAdded(_token, _amount);
    }

    /// @notice Remove liquidity from the pool (admin only)
    /// @param _token Address of the token to withdraw
    /// @param _amount Amount of tokens to withdraw
    function removeLiquidity(address _token, uint256 _amount) external onlyRole(Roles.ADMIN_ROLE) {
        if (_token != token0 && _token != token1) {
            revert InvalidTokenAddress(_token);
        }

        uint256 currentReserve = _token == token0 ? reserveToken0 : reserveToken1;
        require(_amount <= currentReserve, InsufficientReserves());

        require(IERC20(_token).transfer(msg.sender, _amount));

        if (_token == token0) {
            reserveToken0 -= _amount;
        } else {
            reserveToken1 -= _amount;
        }
    }

    /// @notice Grants permission to execute swaps through the pool
    /// @param _swapper Address that will receive the EIP-712 swap role
    /// @notice Grant EIP712 swap permission to an address
    function grantSwapRole(address _swapper) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(Roles.ALLOWED_EIP712_SWAP_ROLE, _swapper);
    }

    /// @notice Revoke EIP712 swap permission from an address
    function revokeSwapRole(address _swapper) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(Roles.ALLOWED_EIP712_SWAP_ROLE, _swapper);
    }

    /// @notice Returns the currently tracked token reserves
    /// @return _reserveToken0 Current reserve of token0
    /// @return _reserveToken1 Current reserve of token1
    function getReserves() external view returns (uint256 _reserveToken0, uint256 _reserveToken1) {
        _reserveToken0 = reserveToken0;
        _reserveToken1 = reserveToken1;
    }

    /// @notice Returns the spot price between two pool reserves
    /// @param _tokenIn Token used as the price denominator
    /// @param _tokenOut Token used as the price numerator
    /// @return _price Current reserve-based price scaled by 1e18
     function getPrice(address _tokenIn, address _tokenOut) external view returns (uint256 _price) {

        uint256 _reserveTokenIn = _tokenIn == token0 ? reserveToken0 : reserveToken1;
        uint256 _reserveTokenOut = _tokenOut == token0 ? reserveToken0 : reserveToken1;

        if (_reserveTokenIn == 0 || _reserveTokenOut == 0) {
            return 0;
        }

        _price = (_reserveTokenOut * 1e18) / _reserveTokenIn;
    }

    /// @notice Executes a token swap using the pool's current reserves
    /// @param _sender Address supplying the input tokens and receiving output tokens
    /// @param _tokenIn Address of the input token
    /// @param _tokenOut Address of the output token
    /// @param _amountIn Amount of input tokens to swap
    /// @param _minAmountOut Minimum output amount accepted by the sender
    function swap(address _sender, address _tokenIn, address _tokenOut, uint256 _amountIn, uint256 _minAmountOut)
        external
        nonReentrant
        onlyAdminOrEIP712Swap
    {
        if (
            _tokenIn != token0 && _tokenIn != token1 || _tokenOut != token0 && _tokenOut != token1
                || _tokenIn == _tokenOut
        ) {
            revert InvalidTokenPair(_tokenIn, _tokenOut);
        }

        address tokenHolder = _sender;

        if (IERC20(_tokenIn).allowance(tokenHolder, address(this)) < _amountIn) revert InsufficientAllowance();

        uint256 _reserveTokenIn = _tokenIn == token0 ? reserveToken0 : reserveToken1;
        uint256 _reserveTokenOut = _tokenOut == token0 ? reserveToken0 : reserveToken1;

        if (_reserveTokenIn == 0 || _reserveTokenOut == 0) revert InsufficientLiquidity();
        if (_amountIn >= _reserveTokenIn) revert InsufficientLiquidity();

        // AMM calculation
        uint256 amountOut = (_amountIn * _reserveTokenOut) / (_reserveTokenIn + _amountIn);

        ISwap.SwapParams memory swapParams = ISwap.SwapParams({
            token0: _tokenIn,
            token1: _tokenOut,
            amount0: _amountIn,
            reserveToken0: _reserveTokenIn,
            reserveToken1: _reserveTokenOut
        });

        uint256 feeAmount = feeManager.getFee(swapParams);
        amountOut = amountOut > feeAmount ? amountOut - feeAmount : 0;

        if (amountOut < _minAmountOut) revert InsufficientOutputAmount(_minAmountOut, amountOut);

        if (_tokenIn == token0) {
            reserveToken0 += _amountIn;
            reserveToken1 -= amountOut;
        } else {
            reserveToken1 += _amountIn;
            reserveToken0 -= amountOut;
        }

        require(IERC20(_tokenIn).transferFrom(tokenHolder, address(this), _amountIn));
        require(IERC20(_tokenOut).transfer(tokenHolder, amountOut));

        emit Swap(_tokenIn, _tokenOut, _amountIn, amountOut);
    }
}