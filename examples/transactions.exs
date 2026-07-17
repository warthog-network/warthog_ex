#!/usr/bin/env elixir
# Examples demonstrating how to use warthog_ex to build and submit
# transactions on the Warthog network.
#
# Run with:
#   mix run examples/transactions.exs

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

account = Account.from_random()

IO.puts("Private Key: #{account.private_key_hex}")
IO.puts("Public Key:  #{account.public_key_hex}")
IO.puts("Address:     #{account.address.hex}")

existing_account =
  Account.from_private_key_hex!(
    "966a71a98bb5d13e9116c0dffa3f1a7877e45c6f563897b96cfd5c59bf0803e0"
  )

IO.puts("Loaded Address: #{existing_account.address.hex}")

api = WarthogApi.new("http://127.0.0.1:3100")

submit = fn tx ->
  label = Map.get(tx, :type)
  result = WarthogApi.submit_transaction(api, tx)

  case result do
    {:ok, %{txHash: hash}} ->
      IO.puts("#{label} submitted successfully!")
      IO.puts("Transaction hash: #{hash}")

    {:error, _} = err ->
      IO.puts("#{label} failed: #{inspect(err)}")
  end
end

run_examples = fn ->
  {:ok, ctx} =
    WarthogApi.create_transaction_context(api, RoundedFee.min(), NonceId.from_number!(0))

  recipient = Address.from_hex!("0000000000000000000000000000000000000000de47c9b2")
  asset = "f45b113119c7f7c000234f1090d5d181ab60b8b24526f1edd2f563aa1ca329f2"
  wart = Wart.from_e8!(100_000_000)
  dec4 = TokenDecimals.new!(4)
  price = Price.from_number_decimals!(1.0, dec4, false)
  dec5 = TokenDecimals.new!(5)

  # WART transfer
  submit.(TransactionContext.transfer_wart(ctx, existing_account, recipient, wart))

  # Asset transfer (transfer regular tokens)
  ctx = %{ctx | nonce_id: NonceId.from_number!(2)}
  submit.(
    TransactionContext.transfer_asset(
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
    TransactionContext.transfer_liquidity(
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
  submit.(TransactionContext.buy(ctx, existing_account, asset, wart, price))

  # Limit sell
  ctx = %{ctx | nonce_id: NonceId.from_number!(6)}
  submit.(
    TransactionContext.sell(ctx, existing_account, asset, Funds.parse!("1000", dec4), price)
  )

  # Liquidity deposit
  ctx = %{ctx | nonce_id: NonceId.from_number!(7)}
  submit.(
    TransactionContext.deposit_liquidity(
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
    TransactionContext.withdraw_liquidity(ctx, existing_account, asset, Liquidity.from_e8!(100))
  )

  # Cancelation
  ctx = %{ctx | nonce_id: NonceId.from_number!(9)}
  submit.(TransactionContext.cancel_transaction(ctx, existing_account, 0, NonceId.from_number!(1)))

  # Asset creation
  ctx = %{ctx | nonce_id: NonceId.from_number!(10)}
  submit.(TransactionContext.create_assets(ctx, existing_account, Funds.parse!("10000", dec5), dec5, "TOK2"))
end

run_examples.()