# warthog_ex

An Elixir library for the [Warthog](https://warthog.network) cryptocurrency.

This is the Elixir port of [`warthog-ts`](https://github.com/warthog-network/warthog-ts) and provides type-safe primitives for building and submitting transactions on the Warthog network.

The two node families are separate APIs, so there is a client and a transaction context for each:

- The **legacy node** (`core/master`, `core/dev`) accepts one kind of transaction, a transfer.
- The **DeFi node** (`core/defi`) accepts the full native DeFi transaction set:

  - `wartTransfer`
  - `tokenTransfer`
  - `assetCreation`
  - `limitSwap`
  - `liquidityDeposit`
  - `liquidityWithdrawal`
  - `cancelation`

## Installation

The package is **not yet published to Hex.pm**. Install it directly from the
GitHub repository by adding the following to your `mix.exs`:

```elixir
def deps do
  [
    {:warthog_ex, github: "warthog-network/warthog_ex"}
  ]
end
```

Then fetch and compile the dependency:

```bash
mix deps.get
mix deps.compile
```

## Quick start

```elixir
alias WarthogEx.{
  Account,
  Address,
  LegacyApi,
  RoundedFee,
  Wart,
  NonceId,
  TransactionContext
}

# 1. Load account
account = Account.from_private_key_hex("your-private-key-hex")

# 2. Prepare recipient
{:ok, recipient} = Address.from_hex("0000000000000000000000000000000000000000de47c9b2")

# 3. Connect to a node. The legacy node takes one kind of transaction, a
#    transfer. The first known legacy node is a public main net node
#    (port 3001).
api = LegacyApi.new()

# 4. Create transaction context (fetches chain pin)
{:ok, context} = LegacyApi.create_transaction_context(api, RoundedFee.min(), NonceId.random())

# 5. Build a WART transfer
tx = TransactionContext.transfer_wart(context, account, recipient, Wart.from_e8(100_000_000) |> elem(1))

# 6. Submit
{:ok, %{txHash: hash}} = LegacyApi.submit_transaction(api, tx)
```

## Modules

| Module | Purpose |
|---|---|
| `WarthogEx.Address` | 20-byte SHA-256-checksummed addresses |
| `WarthogEx.NonceId` | 32-bit transaction nonces |
| `WarthogEx.TokenDecimals` | Number of decimal places for a token |
| `WarthogEx.ParsedFunds` | Parsed decimal strings |
| `WarthogEx.Funds` | Token amounts with decimals |
| `WarthogEx.Wart` | Native WART token (8 decimals) |
| `WarthogEx.Liquidity` | Liquidity pool tokens (8 decimals) |
| `WarthogEx.RoundedFee` | Rounded transaction fees (API-ready) |
| `WarthogEx.CompactFee` | 16-bit compact fee representation |
| `WarthogEx.Price` | Normalized mantissa/exponent prices |
| `WarthogEx.Account` | secp256k1 wallet account |
| `WarthogEx.HDWallet` | BIP-44 hierarchical deterministic wallet |
| `WarthogEx.ChainPin` | Proposed (height, hash) pin for transaction building |
| `WarthogEx.ChainHead` | Normalized `/chain/head` view |
| `WarthogEx.TransactionContext` | The builder both node families share |
| `WarthogEx.LegacyTransactionContext` | Transaction builder for the legacy node |
| `WarthogEx.DeFiTransactionContext` | Transaction builder for the DeFi node |
| `WarthogEx.Api` | HTTP plumbing shared by the node clients |
| `WarthogEx.LegacyApi` | Client for the legacy node |
| `WarthogEx.DeFiApi` | Client for the DeFi node |
| `WarthogEx.DeFiWartBalance` | WART balance on the DeFi node |
| `WarthogEx.TokenBalance` | Token balance on the DeFi node |

### Account

```elixir
account = Account.from_random()
IO.puts("Private key: #{account.private_key_hex}")
IO.puts("Address:     #{account.address.hex}")

existing = Account.from_private_key_hex("966a71a98bb5d13e9116c0dffa3f1a7877e45c6f563897b96cfd5c59bf0803e0")
```

### Address

```elixir
{:ok, addr} = Address.from_hex("0000000000000000000000000000000000000000de47c9b2")
{:ok, addr} = Address.from_raw("0000000000000000000000000000000000000000")
Address.validate("0000000000000000000000000000000000000000de47c9b2")
# => true
```

### NonceId

```elixir
{:ok, nonce} = NonceId.from_number(12345)
nonce = NonceId.random()
NonceId.validate(12345)
# => true
```

### Funds / Wart / Liquidity

```elixir
# 1.5 WART = 150_000_000 E8
{:ok, wart} = Wart.parse("1.5")
{:ok, wart} = Wart.from_e8(150_000_000)

# 1000 units of a 4-decimal token = 10_000_000 internal
{:ok, funds} = Funds.parse("1000", TokenDecimals.new(4))

# Liquidity units
{:ok, liquidity} = Liquidity.from_e8(100)
```

### RoundedFee / CompactFee

```elixir
fee = RoundedFee.min()                       # 1 E8 = 0.00000001 WART
{:ok, fee} = RoundedFee.from_e8(1_000, false)
{:ok, wart} = Wart.parse("1.00000005")
fee = Wart.rounded_fee(wart, false)
```

### Price

```elixir
{:ok, price} = Price.from_number_decimals(1.5, TokenDecimals.wart(), false)
Price.to_hex(price)
# => "c0e74d"

{:ok, price} = Price.from_hex("c0e74d")
Price.to_double_adjusted(price, TokenDecimals.wart())
```

### HDWallet

```elixir
mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
wallet = HDWallet.from_mnemonic(mnemonic)
account0 = HDWallet.derive_account_at_index(wallet, 0)
account1 = HDWallet.derive_account_at_index(wallet, 1)
```

Derivation path: `m/44'/2070'/0'/0/{index}` (Warthog coin type `2070`).

### TransactionContext

`WarthogEx.TransactionContext` is a protocol carrying the one builder both node families have, `transfer_wart/4`. The contexts themselves are separate modules, because the two families accept different transaction sets:

| Context | Node | Builders |
|---|---|---|
| `WarthogEx.LegacyTransactionContext` | `core/master`, `core/dev` | `transfer_wart/4` only |
| `WarthogEx.DeFiTransactionContext` | `core/defi` | all nine |

A legacy context cannot build a limit swap, because that builder does not exist on it. Code that only sends WART can hold either context and call the protocol:

```elixir
WarthogEx.TransactionContext.transfer_wart(ctx, account, recipient, wart)
```

The DeFi-only builders live on `WarthogEx.DeFiTransactionContext`:

| Method | Transaction type |
|---|---|
| `transfer_asset/5` | `tokenTransfer` (asset) |
| `transfer_liquidity/5` | `tokenTransfer` (liquidity) |
| `buy/5` | `limitSwap` (buy) |
| `sell/5` | `limitSwap` (sell) |
| `deposit_liquidity/5` | `liquidityDeposit` |
| `withdraw_liquidity/4` | `liquidityWithdrawal` |
| `cancel_transaction/4` | `cancelation` |
| `create_assets/5` | `assetCreation` |

All return a signed transaction map ready for `submit_transaction/2`.

### The amount field follows the node family

The legacy node reads a transfer's amount from `amountE8`, and its payload carries no `type` at all. The DeFi node reads it from `wartE8`, and on that node the name `amountE8` means the liquidity share count. Both families sign the same bytes for a transfer, so a signature made for one is valid for the other.

### Node clients and balances

```elixir
alias WarthogEx.{Api, DeFiApi, LegacyApi}

legacy = LegacyApi.new()      # a public main net node
defi = DeFiApi.new()          # a public DeFi node

Api.known_nodes_legacy()
Api.known_nodes_defi()

# The legacy node reports one number: the confirmed balance.
{:ok, wart} = LegacyApi.get_wart_balance(legacy, address)

# The DeFi node reports the total, what is locked in open limit orders and
# what is locked by transactions in the mempool.
{:ok, balance} = DeFiApi.get_wart_balance(defi, address)
{:ok, free} = DeFiWartBalance.free(balance)

# A token balance, the DeFi node only.
{:ok, token} = DeFiApi.get_token_balance(defi, address, asset_hash)
```

## Error handling convention

Following standard Elixir practice, every factory function ships in two flavors:

- **`name/1`** — returns `{:ok, t()} | :error`. Use when you need to handle failures gracefully.
- **`name!/1`** — raises `ArgumentError` on invalid input. Use when you trust the input and want a tighter call site.

For example:

```elixir
{:ok, wart} = Wart.parse("1.5")        # safe
Wart.parse!("1.5")                     # raises on invalid
Wart.parse("1.123456789") == :error    # too many decimals for WART (8)
```

Apply the convention to all parsing/validation: `Address.from_hex`, `Wart.parse`, `Funds.parse`, `Price.from_hex`, `TokenDecimals.new`, `NonceId.from_number`, etc.

## Testing

```bash
mix test
```

## Examples

```bash
mix run examples/transactions.exs
```

## License

Released under the MIT License. See `LICENSE` for details.
