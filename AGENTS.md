# AGENTS.md - Warthog Elixir Library

## Overview

Warthog is a cryptocurrency. This library provides type-safe primitives for
building and submitting transactions on the Warthog network. It is the
Elixir port of [`warthog-ts`](https://github.com/warthog-network/warthog-ts).

## Important Constants

- **`MAX_U64`** = `0xffffffffffffffff` (18,446,744,073,709,551,615) — maximum 64-bit unsigned integer. Exposed via `WarthogEx.max_u64/0`.
- **`MAX_U32`** = `0xFFFFFFFF` (4,294,967,295) — maximum 32-bit unsigned integer. Exposed via `WarthogEx.max_u32/0`.
- **WART decimals** = 8 decimal places (`1 WART = 100,000,000 E8`).

## Error-handling convention

Following standard Elixir practice, every factory function ships in two
flavors:

- **`name/1`** — returns `{:ok, t()} | :error`. Use when failures are expected.
- **`name!/1`** — raises `ArgumentError` on invalid input. Use when you trust the input and want a tighter call site.

The convention applies to every parser and validator in the library:
`Address.from_hex`, `Wart.parse`, `Funds.parse`, `Price.from_hex`,
`TokenDecimals.new`, `NonceId.from_number`, etc. Predicates that return
booleans (`Address.validate`, `NonceId.validate`) stay as-is.

## Core Types

### Address
**File:** `lib/warthog_ex/address.ex`

Warthog uses 20-byte addresses with a 4-byte SHA-256 checksum, encoded as
a 48-character hex string.

```elixir
alias WarthogEx.Address

# Create from 48-char hex string (with checksum)
{:ok, addr} = Address.from_hex("0000000000000000000000000000000000000000de47c9b2")

# Create from 40-char raw hex (20 bytes, no checksum)
{:ok, addr} = Address.from_raw("0000000000000000000000000000000000000000")

# Bang versions (raise on invalid input)
addr = Address.from_hex!("0000000000000000000000000000000000000000de47c9b2")
addr = Address.from_raw!("0000000000000000000000000000000000000000")

# Validate any address string (returns boolean)
Address.validate("0000000000000000000000000000000000000000de47c9b2")
# => true
```

### NonceId
**File:** `lib/warthog_ex/nonce_id.ex`

Every transaction needs a unique nonce (32-bit unsigned integer: 0 to
4,294,967,295).

```elixir
alias WarthogEx.NonceId

{:ok, nonce} = NonceId.from_number(12345)
nonce = NonceId.from_number!(12345)
nonce = NonceId.random()
NonceId.validate(12345)  # => true
```

### TokenDecimals
**File:** `lib/warthog_ex/token_decimals.ex`

Represents the number of decimal places for a token (0–18).

```elixir
alias WarthogEx.TokenDecimals

# Pre-configured
TokenDecimals.wart()       # 8 decimals
TokenDecimals.liquidity()  # 8 decimals

# Custom
{:ok, td} = TokenDecimals.new(4)
td = TokenDecimals.new!(4)
```

### ParsedFunds
**File:** `lib/warthog_ex/parsed_funds.ex`

Parses a decimal string into an integer plus a decimal-place count.

```elixir
alias WarthogEx.ParsedFunds

{:ok, parsed} = ParsedFunds.parse("123.45")
# parsed.val            # => 12345
# parsed.decimal_places # => 2

parsed = ParsedFunds.parse!("123.45")
```

### Funds
**File:** `lib/warthog_ex/funds.ex`

Represents a token amount with a specific number of decimal places.

```elixir
alias WarthogEx.{Funds, TokenDecimals}

{:ok, f} = Funds.parse("1.123", TokenDecimals.new!(4))
# f.amount # => 11230

f = Funds.parse!("1.123", TokenDecimals.new!(4))
```

### Wart
**File:** `lib/warthog_ex/wart.ex`

Warthog's native token (8 decimal places).

```elixir
alias WarthogEx.Wart

{:ok, w} = Wart.parse("1.5")
# w.e8 # => 150_000_000

{:ok, w} = Wart.from_e8(150_000_000)
w = Wart.from_e8!(150_000_000)
w = Wart.parse!("1.5")

# Convert to a RoundedFee (pass `true` to round up, `false` to round down)
fee = Wart.rounded_fee(w, false)
```

### Liquidity
**File:** `lib/warthog_ex/liquidity.ex`

Liquidity pool tokens with 8 decimal places. Used for liquidity
deposit/withdrawal transactions.

```elixir
alias WarthogEx.Liquidity

{:ok, l} = Liquidity.parse("1.5")
{:ok, l} = Liquidity.from_e8(100)
l = Liquidity.from_e8!(100)
l = Liquidity.parse!("1.5")
```

### RoundedFee
**File:** `lib/warthog_ex/rounded_fee.ex`

Transaction fees in rounded WART format (64-bit WART scale).

This is **not** the 16-bit compact representation. It is the result of:
1. Converting WART to a 16-bit `CompactFee`.
2. Converting back to the WART scale.

This is a lossy operation — the original WART value cannot be restored.
Warthog nodes require rounded values on the 64-bit WART scale in API
calls.

```elixir
alias WarthogEx.{RoundedFee, Wart}

# Minimum fee (0.00000001 WART = 1 E8)
fee = RoundedFee.min()

# Create from E8 value (second arg: `ceil`)
{:ok, fee} = RoundedFee.from_e8(1_000, false)
fee = RoundedFee.from_e8!(1_000, false)

# Round from Wart
fee = Wart.rounded_fee(Wart.parse!("1.00000005"), false)

# Convert back to Wart
wart = RoundedFee.to_wart(fee)
```

### CompactFee
**File:** `lib/warthog_ex/compact_fee.ex`

Warthog's internal 16-bit compact fee representation. Used for compact
storage and transmission within the protocol.

**Note:** This is *not* used in transaction submission API — use
`RoundedFee` instead.

```elixir
alias WarthogEx.{CompactFee, Wart}

cf = CompactFee.from_wart(Wart.parse!("1.5"), false)
wart = CompactFee.to_wart(cf)
```

### Price
**File:** `lib/warthog_ex/price.ex`

Represents a swap price in normalized mantissa/exponent format.

- **Mantissa:** 16 bits, must be in `[0x8000, 0xFFFF]` (high bit set).
- **Exponent:** 8 bits, stored with offset `+63` internally to map to `[0, 127]`.

```elixir
alias WarthogEx.{Price, TokenDecimals}

# Maximum price
Price.max()

# Create from raw mantissa and exponent (supply values BEFORE the +63 adjustment)
{:ok, price} = Price.from_mantissa_exponent(0x8000, 0)
price = Price.from_mantissa_exponent!(0x8000, 0)

# Parse from 6-char hex
{:ok, price} = Price.from_hex("c0e74d")
price = Price.from_hex!("c0e74d")

# Create from a double with the base asset's decimals
{:ok, price} = Price.from_number_decimals(1.5, TokenDecimals.wart(), false)
price = Price.from_number_decimals!(1.5, TokenDecimals.wart())

# Convert to hex for transaction generation
Price.to_hex(price)
# => "c0e74d"

# Convert to double (raw, without decimals adjustment)
Price.to_double_raw(price)

# Convert to double (with asset-decimals adjustment)
Price.to_double_adjusted(price, TokenDecimals.wart())
```

## Account & Wallets

### Account
**File:** `lib/warthog_ex/account.ex`

Wallet account for signing transactions. Uses secp256k1 elliptic curve.
The address is derived as
`RIPEMD-160(SHA-256(compressed-public-key))` with a 4-byte SHA-256
checksum appended.

```elixir
alias WarthogEx.Account

# Generate new random account
account = Account.from_random()

# Load from a 64-character hex private key
{:ok, account} = Account.from_private_key_hex("966a71a98bb5d13e9116c0dffa3f1a7877e45c6f563897b96cfd5c59bf0803e0")
account = Account.from_private_key_hex!("966a71a98bb5d13e9116c0dffa3f1a7877e45c6f563897b96cfd5c59bf0803e0")

# Fields (public struct fields, not methods)
account.private_key_hex
account.public_key_hex
account.address

# Sign arbitrary bytes (SHA-256 of the message, same scheme as tx sigs)
{:ok, {r, s, recid, signature_hex}} = Account.sign_bytes(account, "hello world")
{:ok, _} = Account.sign_bytes!(account, "hello world")
# signature_hex is 130-char lowercase hex (r || s || recid)

# Recover the compressed public key (hex, 66 chars) from a signature.
# signature accepts either {r, s, recid} tuple or 130-char hex string.
{:ok, pubkey_hex} = Account.recover_public_key("hello world", signature_hex)
pubkey_hex = Account.recover_public_key!("hello world", signature_hex)

# Recover the Warthog address that produced a signature.
{:ok, address} = Account.recover_address("hello world", signature_hex)
address = Account.recover_address!("hello world", signature_hex)
```

### HDWallet
**File:** `lib/warthog_ex/hd_wallet.ex`

BIP-44 hierarchical deterministic wallet. Derivation path
`m/44'/2070'/0'/0/{index}` (Warthog coin type `2070`).

```elixir
alias WarthogEx.HDWallet

mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
wallet = HDWallet.from_mnemonic(mnemonic)

# Derive account at index
account = HDWallet.derive_account_at_index(wallet, 0)

# Derive from a custom relative path (with or without the "m/" prefix)
account = HDWallet.derive_account_from_path(wallet, "0/0")
account = HDWallet.derive_account_from_path(wallet, "m/0/0")
```

## Transaction Building

### TransactionContext
**File:** `lib/warthog_ex/transaction_context.ex`

Builds and signs transactions. Obtain via
`WarthogApi.create_transaction_context/3`. The context's `chain_pin`,
`fee`, and `nonce_id` are all mutable — change `nonce_id` between
transactions to avoid collisions.

```elixir
alias WarthogEx.TransactionContext

# WART transfer
TransactionContext.transfer_wart(ctx, account, recipient, wart)

# Asset transfer (transfer regular tokens)
TransactionContext.transfer_asset(ctx, account, asset_hash, recipient, funds)

# Liquidity transfer (transfer liquidity pool tokens)
TransactionContext.transfer_liquidity(ctx, account, asset_hash, recipient, units)

# Buy (spend WART to buy tokens)
TransactionContext.buy(ctx, account, asset_hash, wart_amount, limit)

# Sell (sell tokens for WART)
TransactionContext.sell(ctx, account, asset_hash, token_amount, limit)

# Deposit liquidity into pool
TransactionContext.deposit_liquidity(ctx, account, asset_hash, token_amount, wart)

# Withdraw liquidity from pool
TransactionContext.withdraw_liquidity(ctx, account, asset_hash, units)

# Cancel transaction
TransactionContext.cancel_transaction(ctx, account, cancel_height, cancel_nonce_id)

# Create assets
TransactionContext.create_assets(ctx, account, total_supply, decimals, name)
```

All return a signed transaction map (with a `signature65` field) ready
for `WarthogApi.submit_transaction/2`.

## API Communication

### WarthogApi
**File:** `lib/warthog_ex/warthog_api.ex`

Client for communicating with Warthog nodes.

```elixir
alias WarthogEx.WarthogApi

# Connect to a node
api = WarthogApi.new()  # defaults to the first known_nodes() entry (public testnet)

# Create a transaction context (fetches chain pin)
{:ok, ctx} = WarthogApi.create_transaction_context(api, fee, nonce)

# Submit a signed transaction
{:ok, %{txHash: hash}} = WarthogApi.submit_transaction(api, tx)

# Fetch chain head directly
{:ok, %{"chainHead" => %{"pinHash" => h, "pinHeight" => n}}} = WarthogApi.get_chain_head(api)

# Known public node URLs
WarthogApi.known_nodes()
```

## Common Patterns

### Full Transaction Flow

```elixir
alias WarthogEx.{
  Account,
  Address,
  Funds,
  Liquidity,
  NonceId,
  Price,
  RoundedFee,
  TokenDecimals,
  TransactionContext,
  Wart,
  WarthogApi
}

# 1. Load your account
account = Account.from_private_key_hex!("your-private-key-hex")

# 2. Prepare the recipient
recipient = Address.from_hex!("0000000000000000000000000000000000000000de47c9b2")

# 3. Connect to the API
api = WarthogApi.new()  # defaults to the first known_nodes() entry (public testnet)

# 4. Create a transaction context (fetches chain pin)
{:ok, context} = WarthogApi.create_transaction_context(api, RoundedFee.min(), NonceId.random())

# 5. Build and sign a WART transfer
tx = TransactionContext.transfer_wart(context, account, recipient, Wart.from_e8!(100_000_000))

# 6. Submit
case WarthogApi.submit_transaction(api, tx) do
  {:ok, %{txHash: hash}} -> IO.puts("Submitted: #{hash}")
  {:error, %{error: reason}} -> IO.puts("Failed: #{reason}")
end
```

### Reusing a context for multiple transactions

The `nonce_id` must be changed between transactions to avoid collisions.
Other fields may stay the same.

```elixir
{:ok, ctx} = WarthogApi.create_transaction_context(api, RoundedFee.min(), NonceId.from_number!(0))

ctx = %{ctx | nonce_id: NonceId.from_number!(1)}
tx1 = TransactionContext.transfer_wart(ctx, account, recipient, Wart.from_e8!(100_000_000))

ctx = %{ctx | nonce_id: NonceId.from_number!(2)}
tx2 = TransactionContext.transfer_asset(ctx, account, asset_hash, recipient, funds)
```

## Testing

```bash
mix test
```

## Examples

```bash
mix run examples/transactions.exs
```

## Version bumping

`just` recipes mirror the `core/defi` convention. Requires [`just`](https://github.com/casey/just).

```bash
just bump          # 0.1.0 -> 0.1.1   (patch)
just bump-minor    # 0.1.1 -> 0.2.0   (minor)
just bump-major    # 0.2.0 -> 1.0.0   (major)
```

The recipes edit `mix.exs` in place using `sed`. No extra dependencies.

## Building / Installing locally

```bash
mix deps.get
mix compile
```

Add to your project's `mix.exs`:

```elixir
def deps do
  [
    {:warthog_ex, "~> 0.1.0"}
  ]
end
```

## Differences from `warthog-ts`

- **Naming**: `Account.fromRandom()` → `Account.from_random/0`,
  `wart.roundedFee(true)` → `Wart.rounded_fee(wart, true)`.
- **Errors**: `null` in TypeScript → `:error` in Elixir; successful values
  are wrapped in `{:ok, value}` tuples.
- **Bang convention**: every factory ships as both `name/1` (returns
  `{:ok, t()} | :error`) and `name!/1` (raises `ArgumentError`).
- **Struct fields**: `account.address` and `account.privateKeyHex` are
  public struct fields, not methods like `getAddress()` / `getPrivateKeyHex()`.