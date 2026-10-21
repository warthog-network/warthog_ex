defmodule WarthogEx.LegacyTransactionContextTest do
  use ExUnit.Case, async: true

  alias WarthogEx.Account
  alias WarthogEx.Address
  alias WarthogEx.ChainPin
  alias WarthogEx.LegacyTransactionContext
  alias WarthogEx.NonceId
  alias WarthogEx.RoundedFee
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
    ctx = LegacyTransactionContext.new(chain_pin, fee, nonce_id)

    {:ok, ctx: ctx, account: account, recipient: recipient}
  end

  test "transfer_wart builds a valid signed transaction", %{
    ctx: ctx,
    account: account,
    recipient: recipient
  } do
    wart = Wart.from_e8!(100_000_000)
    tx = TransactionContext.transfer_wart(ctx, account, recipient, wart)

    assert tx.pinHeight == 32
    assert tx.nonceId == 0
    assert tx.feeE8 == 1
    assert tx.toAddr == recipient.hex
    assert tx.amountE8 == 100_000_000
    assert byte_size(Base.decode16!(tx.signature65, case: :lower)) == 65
  end

  test "the payload carries no type, because the legacy node never reads one", %{
    ctx: ctx,
    account: account,
    recipient: recipient
  } do
    wart = Wart.from_e8!(100_000_000)
    tx = TransactionContext.transfer_wart(ctx, account, recipient, wart)

    refute Map.has_key?(tx, :type)
    refute Map.has_key?(tx, :wartE8)
  end

  test "the legacy context has no DeFi-only builders" do
    # The two node families are separate APIs, so a legacy context cannot
    # build a limit swap: the method does not exist on it.
    refute function_exported?(WarthogEx.LegacyTransactionContext, :transfer_asset, 5)
    refute function_exported?(WarthogEx.LegacyTransactionContext, :buy, 5)
    refute function_exported?(WarthogEx.LegacyTransactionContext, :deposit_liquidity, 6)
  end
end
