defmodule WarthogEx.TransactionContextTest do
  use ExUnit.Case, async: true

  alias WarthogEx.Account
  alias WarthogEx.Address
  alias WarthogEx.Funds
  alias WarthogEx.Liquidity
  alias WarthogEx.NonceId
  alias WarthogEx.Price
  alias WarthogEx.RoundedFee
  alias WarthogEx.TokenDecimals
  alias WarthogEx.TransactionContext
  alias WarthogEx.Wart

  setup do
    private_key_hex = "966a71a98bb5d13e9116c0dffa3f1a7877e45c6f563897b96cfd5c59bf0803e0"

    account = Account.from_private_key_hex!(private_key_hex)
    recipient = Address.from_hex!("0000000000000000000000000000000000000000de47c9b2")

    chain_pin = %{
      pin_hash: String.duplicate("0", 64),
      pin_height: 1
    }

    fee = RoundedFee.min()
    nonce_id = NonceId.from_number!(0)
    ctx = TransactionContext.new(chain_pin, fee, nonce_id)

    {:ok, ctx: ctx, account: account, recipient: recipient}
  end

  test "transfer_wart builds a valid signed transaction", %{
    ctx: ctx,
    account: account,
    recipient: recipient
  } do
    wart = Wart.from_e8!(100_000_000)
    tx = TransactionContext.transfer_wart(ctx, account, recipient, wart)

    assert tx.type == "wartTransfer"
    assert tx.pinHeight == 1
    assert tx.nonceId == 0
    assert tx.feeE8 == 1
    assert tx.toAddr == recipient.hex
    assert tx.wartE8 == 100_000_000
    assert byte_size(Base.decode16!(tx.signature65, case: :lower)) == 65
  end

  test "transfer_asset builds a token transfer transaction", %{
    ctx: ctx,
    account: account,
    recipient: recipient
  } do
    asset_hash = "f45b113119c7f7c000234f1090d5d181ab60b8b24526f1edd2f563aa1ca329f2"
    amount = Funds.parse!("1000", TokenDecimals.wart())
    tx = TransactionContext.transfer_asset(ctx, account, asset_hash, recipient, amount)

    assert tx.type == "tokenTransfer"
    assert tx.assetHash == asset_hash
    assert tx.isLiquidity == false
    assert tx.toAddr == recipient.hex
    assert tx.amountU64 == 100_000_000_000
  end

  test "transfer_liquidity builds a liquidity transfer", %{
    ctx: ctx,
    account: account,
    recipient: recipient
  } do
    asset_hash = "f45b113119c7f7c000234f1090d5d181ab60b8b24526f1edd2f563aa1ca329f2"
    units = Liquidity.from_e8!(100)
    tx = TransactionContext.transfer_liquidity(ctx, account, asset_hash, recipient, units)

    assert tx.type == "tokenTransfer"
    assert tx.isLiquidity == true
    assert tx.amountU64 == 100
  end

  test "buy builds a limit buy transaction", %{ctx: ctx, account: account} do
    asset_hash = "f45b113119c7f7c000234f1090d5d181ab60b8b24526f1edd2f563aa1ca329f2"
    wart = Wart.from_e8!(100_000_000)
    price = Price.from_number_decimals!(1.0, %TokenDecimals{decimals: 4}, false)
    tx = TransactionContext.buy(ctx, account, asset_hash, wart, price)

    assert tx.type == "limitSwap"
    assert tx.isBuy == true
    assert tx.amountU64 == 100_000_000
    assert byte_size(tx.limit) == 6
  end

  test "sell builds a limit sell transaction", %{ctx: ctx, account: account} do
    asset_hash = "f45b113119c7f7c000234f1090d5d181ab60b8b24526f1edd2f563aa1ca329f2"
    amount = Funds.parse!("1000", %TokenDecimals{decimals: 4})
    price = Price.from_number_decimals!(1.0, %TokenDecimals{decimals: 4}, false)
    tx = TransactionContext.sell(ctx, account, asset_hash, amount, price)

    assert tx.type == "limitSwap"
    assert tx.isBuy == false
    assert tx.amountU64 == amount.amount
  end

  test "deposit_liquidity builds a deposit transaction", %{ctx: ctx, account: account} do
    asset_hash = "f45b113119c7f7c000234f1090d5d181ab60b8b24526f1edd2f563aa1ca329f2"
    token_amount = Funds.parse!("1000", %TokenDecimals{decimals: 4})
    wart = Wart.from_e8!(100_000_000)
    tx = TransactionContext.deposit_liquidity(ctx, account, asset_hash, token_amount, wart)

    assert tx.type == "liquidityDeposit"
    assert tx.amountU64 == token_amount.amount
    assert tx.wartE8 == 100_000_000
  end

  test "withdraw_liquidity builds a withdrawal transaction", %{
    ctx: ctx,
    account: account
  } do
    asset_hash = "f45b113119c7f7c000234f1090d5d181ab60b8b24526f1edd2f563aa1ca329f2"
    units = Liquidity.from_e8!(100)
    tx = TransactionContext.withdraw_liquidity(ctx, account, asset_hash, units)

    assert tx.type == "liquidityWithdrawal"
    assert tx.amountE8 == 100
  end

  test "cancel_transaction builds a cancelation", %{ctx: ctx, account: account} do
    cancel_nonce_id = NonceId.from_number!(1)
    tx = TransactionContext.cancel_transaction(ctx, account, 0, cancel_nonce_id)

    assert tx.type == "cancelation"
    assert tx.cancelHeight == 0
    assert tx.cancelNonceId == 1
  end

  test "create_assets builds an asset-creation transaction", %{ctx: ctx, account: account} do
    dec = TokenDecimals.new!(5)
    supply = Funds.parse!("10000", dec)
    tx = TransactionContext.create_assets(ctx, account, supply, dec, "TOK2")

    assert tx.type == "assetCreation"
    assert tx.decimals == 5
    assert tx.name == "TOK2"
    assert tx.supplyU64 == supply.amount
  end

  test "all transactions include valid 65-byte signatures", %{
    ctx: ctx,
    account: account,
    recipient: recipient
  } do
    asset_hash = "f45b113119c7f7c000234f1090d5d181ab60b8b24526f1edd2f563aa1ca329f2"
    wart = Wart.from_e8!(100_000_000)
    amount = Funds.parse!("1000", TokenDecimals.wart())
    units = Liquidity.from_e8!(100)
    price = Price.from_number_decimals!(1.0, %TokenDecimals{decimals: 4}, false)
    token_amount = Funds.parse!("1000", %TokenDecimals{decimals: 4})
    dec = TokenDecimals.new!(5)
    supply = Funds.parse!("10000", dec)
    cancel_nonce_id = NonceId.from_number!(1)

    txs = [
      TransactionContext.transfer_wart(ctx, account, recipient, wart),
      TransactionContext.transfer_asset(ctx, account, asset_hash, recipient, amount),
      TransactionContext.transfer_liquidity(ctx, account, asset_hash, recipient, units),
      TransactionContext.buy(ctx, account, asset_hash, wart, price),
      TransactionContext.sell(ctx, account, asset_hash, token_amount, price),
      TransactionContext.deposit_liquidity(ctx, account, asset_hash, token_amount, wart),
      TransactionContext.withdraw_liquidity(ctx, account, asset_hash, units),
      TransactionContext.cancel_transaction(ctx, account, 0, cancel_nonce_id),
      TransactionContext.create_assets(ctx, account, supply, dec, "TOK2")
    ]

    for tx <- txs do
      sig_bytes = Base.decode16!(tx.signature65, case: :lower)
      assert byte_size(sig_bytes) == 65
    end
  end
end
