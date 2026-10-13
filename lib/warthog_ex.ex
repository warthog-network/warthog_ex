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
      iex> api = WarthogApi.new(:v1)  # first known_nodes() entry, which is a main net node
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
    * `WarthogEx.ChainPin` — proposed (height, hash) pin for transaction building
    * `WarthogEx.ChainHead` — normalized `/chain/head` view
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

  @typedoc """
  Which generation of `/chain/head` JSON a node returns.

  Both generations serialize the same C++ type, `Head { ChainHead chainHead;
  bool synced; }`. Only the serializer differs:

    * **V1** — `core/master` and `core/dev`. A hand-written
      `to_json(API::Head&)` flattens ChainHead field-by-field into the top
      level; `synced` stays at the root.
      `{ hash, height, pinHash, pinHeight, ..., synced }`

    * **V2** — `core/defi` (the DeFi branch). Glaze auto-serialization reflects
      the nested struct, so ChainHead is wrapped; `synced` sits beside it.
      `{ chainHead: { hash, height, pinHash, pinHeight, ... }, synced }`

  The two are NOT interchangeable. Both carry the same fields, so validation is
  identical. Only the location differs.
  """
  @type api_version :: :v1 | :v2

  @doc """
  The supported `/chain/head` API generations.
  """
  @spec api_versions() :: [api_version()]
  def api_versions, do: [:v1, :v2]

  @doc """
  Whether `version` is a supported API generation.
  """
  @spec valid_api_version?(term()) :: boolean()
  def valid_api_version?(version), do: version in [:v1, :v2]
end
