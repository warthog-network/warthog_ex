defmodule WarthogEx.DeFiTransactionContextTest do
  use ExUnit.Case, async: true

  alias WarthogEx.Account
  alias WarthogEx.Address
  alias WarthogEx.ChainPin
  alias WarthogEx.DeFiTransactionContext
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

    chain_pin = %ChainPin{
      pin_hash: String.duplicate("0", 64),
      pin_height: 32
    }

    fee = RoundedFee.min()
    nonce_id = NonceId.from_number!(0)
    ctx = DeFiTransactionContext.new(chain_pin, fee, nonce_id)

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
    assert tx.pinHeight == 32
    assert tx.nonceId == 0
    assert tx.feeE8 == 1
    assert tx.toAddr == recipient.hex
    assert tx.wartE8 == 100_000_000
    assert byte_size(Base.decode16!(tx.signature65, case: :lower)) == 65
  end

  test "the amount goes in wartE8, not amountE8", %{
    ctx: ctx,
    account: account,
    recipient: recipient
  } do
    # On the DeFi node the name amountE8 means the liquidity share count, so
    # the WART amount has to travel as wartE8.
    wart = Wart.from_e8!(100_000_000)
    tx = TransactionContext.transfer_wart(ctx, account, recipient, wart)

    assert tx.wartE8 == 100_000_000
    refute Map.has_key?(tx, :amountE8)
  end

  test "transfer_asset builds a token transfer transaction", %{
    ctx: ctx,
    account: account,
    recipient: recipient
  } do
    asset_hash = "f45b113119c7f7c000234f1090d5d181ab60b8b24526f1edd2f563aa1ca329f2"
    amount = Funds.parse!("1000", TokenDecimals.wart())
    tx = DeFiTransactionContext.transfer_asset(ctx, account, asset_hash, recipient, amount)

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
    tx = DeFiTransactionContext.transfer_liquidity(ctx, account, asset_hash, recipient, units)

    assert tx.type == "tokenTransfer"
    assert tx.isLiquidity == true
    assert tx.amountU64 == 100
  end

  test "buy builds a limit buy transaction", %{ctx: ctx, account: account} do
    asset_hash = "f45b113119c7f7c000234f1090d5d181ab60b8b24526f1edd2f563aa1ca329f2"
    wart = Wart.from_e8!(100_000_000)
    price = Price.from_number_decimals!(1.0, %TokenDecimals{decimals: 4}, false)
    tx = DeFiTransactionContext.buy(ctx, account, asset_hash, wart, price)

    assert tx.type == "limitSwap"
    assert tx.isBuy == true
    assert tx.amountU64 == 100_000_000
    assert byte_size(tx.limit) == 6
  end

  test "sell builds a limit sell transaction", %{ctx: ctx, account: account} do
    asset_hash = "f45b113119c7f7c000234f1090d5d181ab60b8b24526f1edd2f563aa1ca329f2"
    amount = Funds.parse!("1000", %TokenDecimals{decimals: 4})
    price = Price.from_number_decimals!(1.0, %TokenDecimals{decimals: 4}, false)
    tx = DeFiTransactionContext.sell(ctx, account, asset_hash, amount, price)

    assert tx.type == "limitSwap"
    assert tx.isBuy == false
    assert tx.amountU64 == amount.amount
  end

  test "deposit_liquidity builds a deposit transaction", %{ctx: ctx, account: account} do
    asset_hash = "f45b113119c7f7c000234f1090d5d181ab60b8b24526f1edd2f563aa1ca329f2"
    token_amount = Funds.parse!("1000", %TokenDecimals{decimals: 4})
    wart = Wart.from_e8!(100_000_000)
    tx = DeFiTransactionContext.deposit_liquidity(ctx, account, asset_hash, token_amount, wart)

    assert tx.type == "liquidityDeposit"
    # The token amount travels as amountU64. amountE8 is the liquidity share
    # count, which is what a withdrawal carries.
    assert tx.amountU64 == token_amount.amount
    assert tx.wartE8 == 100_000_000
  end

  test "withdraw_liquidity builds a withdrawal transaction", %{
    ctx: ctx,
    account: account
  } do
    asset_hash = "f45b113119c7f7c000234f1090d5d181ab60b8b24526f1edd2f563aa1ca329f2"
    units = Liquidity.from_e8!(100)
    tx = DeFiTransactionContext.withdraw_liquidity(ctx, account, asset_hash, units)

    assert tx.type == "liquidityWithdrawal"
    assert tx.amountE8 == 100
  end

  test "cancel_transaction builds a cancelation", %{ctx: ctx, account: account} do
    cancel_nonce_id = NonceId.from_number!(1)
    tx = DeFiTransactionContext.cancel_transaction(ctx, account, 0, cancel_nonce_id)

    assert tx.type == "cancelation"
    assert tx.cancelHeight == 0
    assert tx.cancelNonceId == 1
  end

  test "create_assets builds an asset-creation transaction", %{ctx: ctx, account: account} do
    dec = TokenDecimals.new!(5)
    supply = Funds.parse!("10000", dec)
    tx = DeFiTransactionContext.create_assets(ctx, account, supply, dec, "TOK2")

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
      DeFiTransactionContext.transfer_asset(ctx, account, asset_hash, recipient, amount),
      DeFiTransactionContext.transfer_liquidity(ctx, account, asset_hash, recipient, units),
      DeFiTransactionContext.buy(ctx, account, asset_hash, wart, price),
      DeFiTransactionContext.sell(ctx, account, asset_hash, token_amount, price),
      DeFiTransactionContext.deposit_liquidity(ctx, account, asset_hash, token_amount, wart),
      DeFiTransactionContext.withdraw_liquidity(ctx, account, asset_hash, units),
      DeFiTransactionContext.cancel_transaction(ctx, account, 0, cancel_nonce_id),
      DeFiTransactionContext.create_assets(ctx, account, supply, dec, "TOK2")
    ]

    for tx <- txs do
      sig_bytes = Base.decode16!(tx.signature65, case: :lower)
      assert byte_size(sig_bytes) == 65
    end
  end

  test "both families sign the same bytes for a transfer", %{
    ctx: ctx,
    account: account,
    recipient: recipient
  } do
    # The signed bytes are identical, only the JSON around them differs, so a
    # signature produced for one family is valid for the other.
    wart = Wart.from_e8!(100_000_000)
    legacy_ctx = WarthogEx.LegacyTransactionContext.new(ctx.chain_pin, ctx.fee, ctx.nonce_id)

    legacy = TransactionContext.transfer_wart(legacy_ctx, account, recipient, wart)
    defi = TransactionContext.transfer_wart(ctx, account, recipient, wart)

    assert legacy.signature65 == defi.signature65
  end
end
