#!/usr/bin/env elixir
# Examples demonstrating how to use warthog_ex to build and submit
# transactions on the Warthog network.
#
# Run with:
#   mix run examples/transactions.exs

alias WarthogEx.{
  Account,
  Address,
  Api,
  DeFiApi,
  DeFiTransactionContext,
  Funds,
  LegacyApi,
  Liquidity,
  NonceId,
  Price,
  RoundedFee,
  TokenDecimals,
  TransactionContext,
  Wart
}

account = Account.from_random()

IO.puts("Private Key: #{account.private_key_hex}")
IO.puts("Public Key:  #{account.public_key_hex}")
IO.puts("Address:     #{account.address.hex}")

existing_account =
  Account.from_private_key_hex!(
    "966a71a98bb5d13e9116c0dffa3f1a7877e45c6f563897b96cfd5c59bf0803e0"
  )

IO.puts("Loaded Address: #{existing_account.address.hex}")

# The two node families are separate APIs, so they get a client each. The
# legacy node (core/master, core/dev) takes one kind of transaction, a
# transfer. The DeFi node (core/defi) takes nine.
legacy_api = LegacyApi.new()
defi_api = DeFiApi.new()

submit = fn api, tx ->
  label = Map.get(tx, :type, "transfer")
  result = Api.submit_transaction(api, tx)

  case result do
    {:ok, %{txHash: hash}} ->
      IO.puts("#{label} submitted successfully!")
      IO.puts("Transaction hash: #{hash}")

    {:error, _} = err ->
      IO.puts("#{label} failed: #{inspect(err)}")
  end
end

# A WART transfer on the legacy node. The payload carries no type, and the
# amount travels as amountE8.
legacy_recipient = Address.from_hex!("0000000000000000000000000000000000000000de47c9b2")
wart = Wart.from_e8!(100_000_000)

{:ok, legacy_ctx} =
  LegacyApi.create_transaction_context(legacy_api, RoundedFee.min(), NonceId.from_number!(0))

submit.(legacy_api, TransactionContext.transfer_wart(legacy_ctx, existing_account, legacy_recipient, wart))

# The DeFi transactions. On that node the amount of a WART transfer travels
# as wartE8, and amountE8 means the liquidity share count.
{:ok, ctx} =
  DeFiApi.create_transaction_context(defi_api, RoundedFee.min(), NonceId.from_number!(0))

recipient = Address.from_hex!("0000000000000000000000000000000000000000de47c9b2")
asset = "f45b113119c7f7c000234f1090d5d181ab60b8b24526f1edd2f563aa1ca329f2"
dec4 = TokenDecimals.new!(4)
price = Price.from_number_decimals!(1.0, dec4, false)
dec5 = TokenDecimals.new!(5)

# WART transfer
submit.(defi_api, TransactionContext.transfer_wart(ctx, existing_account, recipient, wart))

# Asset transfer (transfer regular tokens)
ctx = %{ctx | nonce_id: NonceId.from_number!(2)}
submit.(
  defi_api,
  DeFiTransactionContext.transfer_asset(
    ctx,
    existing_account,
    asset,
    recipient,
    Funds.parse!("1000", TokenDecimals.wart())
  )
)

# Liquidity transfer
ctx = %{ctx | nonce_id: NonceId.from_number!(3)}
submit.(
  defi_api,
  DeFiTransactionContext.transfer_liquidity(
    ctx,
    existing_account,
    asset,
    recipient,
    Liquidity.from_e8!(100)
  )
)

# Limit buy
ctx = %{ctx | nonce_id: NonceId.from_number!(5)}
IO.puts("Price hex: #{Price.to_hex(price)}")
submit.(defi_api, DeFiTransactionContext.buy(ctx, existing_account, asset, wart, price))

# Limit sell
ctx = %{ctx | nonce_id: NonceId.from_number!(6)}
submit.(
  defi_api,
  DeFiTransactionContext.sell(ctx, existing_account, asset, Funds.parse!("1000", dec4), price)
)

# Liquidity deposit
ctx = %{ctx | nonce_id: NonceId.from_number!(7)}
submit.(
  defi_api,
  DeFiTransactionContext.deposit_liquidity(
    ctx,
    existing_account,
    asset,
    Funds.parse!("1000", dec4),
    wart
  )
)

# Liquidity withdrawal
ctx = %{ctx | nonce_id: NonceId.from_number!(8)}
submit.(
  defi_api,
  DeFiTransactionContext.withdraw_liquidity(
    ctx,
    existing_account,
    asset,
    Liquidity.from_e8!(100)
  )
)

# Cancelation
ctx = %{ctx | nonce_id: NonceId.from_number!(9)}
submit.(
  defi_api,
  DeFiTransactionContext.cancel_transaction(ctx, existing_account, 0, NonceId.from_number!(1))
)

# Asset creation
ctx = %{ctx | nonce_id: NonceId.from_number!(10)}
submit.(
  defi_api,
  DeFiTransactionContext.create_assets(
    ctx,
    existing_account,
    Funds.parse!("10000", dec5),
    dec5,
    "TOK2"
  )
)
