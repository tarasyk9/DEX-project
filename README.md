# DEX Project

A decentralized exchange implemented in Solidity using
a constant-product AMM (x * y = k).

## Features

- ERC20 token swaps
- Constant-product AMM
- Liquidity pools
- Swap fees
- Slippage protection
- Deadline protection
- Upgradeable FeeManager (UUPS)
- Role-based access control
- Foundry tests
- GitHub Actions CI

## Architecture

User
  |
  v
Swap
  |
  +----> Pool
  |
  +----> FeeManager

## AMM

x * y = k

amountOut =
amountIn * reserveOut /
(reserveIn + amountIn)

## Contracts

| Contract | Purpose |
|---|---|
| Swap | Executes swaps |
| FeeManager | Calculates protocol fees |
| ISwap | Shared swap structures/interfaces |

## Security

- Slippage protection
- Deadline validation
- AccessControl
- Reentrancy protection
- Fee bounds

## Testing

forge test -vvv

## Build

forge build