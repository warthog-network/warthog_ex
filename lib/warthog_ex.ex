defmodule WarthogEx do
  @moduledoc """
  WarthogEx is an Elixir library for the Warthog cryptocurrency.

  It provides type-safe primitives for building and submitting transactions
  on the Warthog network. This is the Elixir port of the `warthog-ts`
  TypeScript library.

  ## Quick start

      iex> alias WarthogEx.{
      ...>   Account,
      ...>   Address,
      ...>   RoundedFee,
      ...>   Wart,
      ...>   NonceId,
      ...>   WarthogApi,
      ...>   TransactionContext
      ...> }
      iex> account = Account.from_private_key_hex(\"your-private-key-hex\")
      iex> recipient = Address.from_hex(\"0000000000000000000000000000000000000000de47c9b2\")
      iex> api = WarthogApi.new()  # defaults to first known_nodes() entry (public testnet)
      iex> {:ok, %TransactionContext{} = ctx} = WarthogApi.create_transaction_context(api, RoundedFee.min(), NonceId.random())
      iex> tx = TransactionContext.transfer_wart(ctx, account, recipient, Wart.from_e8(100_000_000))
      iex> {:ok, _} = WarthogApi.submit_transaction(api, tx)

  ## Modules

    * `WarthogEx.Address` — 20-byte SHA-256 checksummed addresses
    * `WarthogEx.NonceId` — 32-bit transaction nonces
    * `WarthogEx.TokenDecimals` — token decimal place count
    * `WarthogEx.ParsedFunds` — parsed decimal-string amounts
    * `WarthogEx.Funds` — token amounts with decimals
    * `WarthogEx.Wart` — native WART token (8 decimals)
    * `WarthogEx.Liquidity` — liquidity pool tokens (8 decimals)
    * `WarthogEx.RoundedFee` — rounded transaction fees
    * `WarthogEx.CompactFee` — 16-bit compact fee representation
    * `WarthogEx.Price` — normalized mantissa/exponent prices
    * `WarthogEx.Account` — secp256k1 wallet account
    * `WarthogEx.HDWallet` — BIP-44 hierarchical deterministic wallet
    * `WarthogEx.TransactionContext` — transaction builder
    * `WarthogEx.WarthogApi` — HTTP client for Warthog nodes
  """

  @doc """
  Maximum 64-bit unsigned integer value (`0xffffffffffffffff`).
  """
  @spec max_u64() :: non_neg_integer()
  def max_u64, do: 0xFFFFFFFFFFFFFFFF

  @doc """
  Maximum 32-bit unsigned integer value (`0xFFFFFFFF`).
  """
  @spec max_u32() :: non_neg_integer()
  def max_u32, do: 0xFFFFFFFF
end
