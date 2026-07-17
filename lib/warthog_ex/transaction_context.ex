defmodule WarthogEx.TransactionContext do
  @moduledoc """
  Transaction builder for creating and signing Warthog transactions.

  Obtained via `WarthogApi.create_transaction_context/3`.

  All properties (`chain_pin`, `fee`, `nonce_id`) can be modified. When reusing
  this context for multiple transactions, you MUST change the `nonce_id` for
  each new transaction to prevent nonce collisions. The `chain_pin` should
  typically remain unchanged unless you need to refresh it from the network.
  """

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

  @type chain_pin :: %{pin_hash: String.t(), pin_height: non_neg_integer()}

  @type transaction :: map()

  defstruct [:chain_pin, :fee, :nonce_id]

  @type t :: %__MODULE__{
          chain_pin: chain_pin(),
          fee: RoundedFee.t(),
          nonce_id: NonceId.t()
        }

  @doc """
  Create a new transaction context.
  """
  @spec new(chain_pin(), RoundedFee.t(), NonceId.t()) :: t()
  def new(%{} = chain_pin, %RoundedFee{} = fee, %NonceId{} = nonce_id) do
    %TransactionContext{chain_pin: chain_pin, fee: fee, nonce_id: nonce_id}
  end

  @doc """
  Build and sign a native WART transfer transaction.
  """
  @spec transfer_wart(t(), Account.t(), Address.t(), Wart.t()) :: transaction()
  def transfer_wart(
        %TransactionContext{} = ctx,
        %Account{} = account,
        %Address{} = to_addr,
        %Wart{} = wart
      ) do
    binary =
      bin(ctx.chain_pin.pin_hash) <>
        u32be(ctx.chain_pin.pin_height) <>
        u32be(ctx.nonce_id.value) <>
        <<0, 0, 0>> <>
        u64be(ctx.fee.e8) <>
        address_bytes(to_addr.hex) <>
        u64be(wart.e8)

    {:ok, {_r, _s, _recid, sig}} = Account.sign(account, sha256(binary))

    %{
      type: "wartTransfer",
      pinHeight: ctx.chain_pin.pin_height,
      nonceId: ctx.nonce_id.value,
      feeE8: ctx.fee.e8,
      toAddr: to_addr.hex,
      wartE8: wart.e8,
      signature65: sig
    }
  end

  @doc """
  Build and sign an asset transfer transaction.
  """
  @spec transfer_asset(t(), Account.t(), String.t(), Address.t(), Funds.t()) :: transaction()
  def transfer_asset(
        %TransactionContext{} = ctx,
        %Account{} = account,
        asset_hash,
        %Address{} = to_addr,
        %Funds{} = amount
      ) do
    token_transfer_internal(ctx, account, asset_hash, false, to_addr, amount.amount)
  end

  @doc """
  Build and sign a liquidity pool token transfer transaction.
  """
  @spec transfer_liquidity(t(), Account.t(), String.t(), Address.t(), Liquidity.t()) ::
          transaction()
  def transfer_liquidity(
        %TransactionContext{} = ctx,
        %Account{} = account,
        asset_hash,
        %Address{} = to_addr,
        %Liquidity{} = units
      ) do
    token_transfer_internal(ctx, account, asset_hash, true, to_addr, units.e8)
  end

  defp token_transfer_internal(ctx, account, asset_hash, is_liquidity, to_addr, amount_e8) do
    binary =
      bin(ctx.chain_pin.pin_hash) <>
        u32be(ctx.chain_pin.pin_height) <>
        u32be(ctx.nonce_id.value) <>
        <<0, 0, 0>> <>
        u64be(ctx.fee.e8) <>
        bin(asset_hash) <>
        <<if(is_liquidity, do: 1, else: 0)>> <>
        address_bytes(to_addr.hex) <>
        u64be(amount_e8)

    {:ok, {_r, _s, _recid, sig}} = Account.sign(account, sha256(binary))

    %{
      type: "tokenTransfer",
      pinHeight: ctx.chain_pin.pin_height,
      nonceId: ctx.nonce_id.value,
      feeE8: ctx.fee.e8,
      assetHash: asset_hash,
      isLiquidity: is_liquidity,
      toAddr: to_addr.hex,
      amountU64: amount_e8,
      signature65: sig
    }
  end

  @doc """
  Build and sign a limit buy transaction (spend WART to buy tokens).
  """
  @spec buy(t(), Account.t(), String.t(), Wart.t(), Price.t()) :: transaction()
  def buy(
        %TransactionContext{} = ctx,
        %Account{} = account,
        asset_hash,
        %Wart{e8: wart_amount},
        %Price{} = limit
      ) do
    limit_swap_internal(ctx, account, asset_hash, true, wart_amount, limit)
  end

  @doc """
  Build and sign a limit sell transaction (sell tokens for WART).
  """
  @spec sell(t(), Account.t(), String.t(), Funds.t(), Price.t()) :: transaction()
  def sell(
        %TransactionContext{} = ctx,
        %Account{} = account,
        asset_hash,
        %Funds{amount: token_amount},
        %Price{} = limit
      ) do
    limit_swap_internal(ctx, account, asset_hash, false, token_amount, limit)
  end

  defp limit_swap_internal(ctx, account, asset_hash, is_buy, amount_e8, limit) do
    binary =
      bin(ctx.chain_pin.pin_hash) <>
        u32be(ctx.chain_pin.pin_height) <>
        u32be(ctx.nonce_id.value) <>
        <<0, 0, 0>> <>
        u64be(ctx.fee.e8) <>
        bin(asset_hash) <>
        <<if(is_buy, do: 1, else: 0)>> <>
        u64be(amount_e8) <>
        bin(Price.to_hex(limit))

    {:ok, {_r, _s, _recid, sig}} = Account.sign(account, sha256(binary))

    %{
      type: "limitSwap",
      pinHeight: ctx.chain_pin.pin_height,
      nonceId: ctx.nonce_id.value,
      feeE8: ctx.fee.e8,
      assetHash: asset_hash,
      isBuy: is_buy,
      amountU64: amount_e8,
      limit: Price.to_hex(limit),
      signature65: sig
    }
  end

  @doc """
  Build and sign a liquidity deposit transaction.
  """
  @spec deposit_liquidity(t(), Account.t(), String.t(), Funds.t(), Wart.t()) :: transaction()
  def deposit_liquidity(
        %TransactionContext{} = ctx,
        %Account{} = account,
        asset_hash,
        %Funds{} = token_amount,
        %Wart{} = wart
      ) do
    binary =
      bin(ctx.chain_pin.pin_hash) <>
        u32be(ctx.chain_pin.pin_height) <>
        u32be(ctx.nonce_id.value) <>
        <<0, 0, 0>> <>
        u64be(ctx.fee.e8) <>
        bin(asset_hash) <>
        u64be(token_amount.amount) <>
        u64be(wart.e8)

    {:ok, {_r, _s, _recid, sig}} = Account.sign(account, sha256(binary))

    %{
      type: "liquidityDeposit",
      pinHeight: ctx.chain_pin.pin_height,
      nonceId: ctx.nonce_id.value,
      feeE8: ctx.fee.e8,
      assetHash: asset_hash,
      amountU64: token_amount.amount,
      wartE8: wart.e8,
      signature65: sig
    }
  end

  @doc """
  Build and sign a liquidity withdrawal transaction.
  """
  @spec withdraw_liquidity(t(), Account.t(), String.t(), Liquidity.t()) :: transaction()
  def withdraw_liquidity(
        %TransactionContext{} = ctx,
        %Account{} = account,
        asset_hash,
        %Liquidity{} = units
      ) do
    binary =
      bin(ctx.chain_pin.pin_hash) <>
        u32be(ctx.chain_pin.pin_height) <>
        u32be(ctx.nonce_id.value) <>
        <<0, 0, 0>> <>
        u64be(ctx.fee.e8) <>
        bin(asset_hash) <>
        u64be(units.e8)

    {:ok, {_r, _s, _recid, sig}} = Account.sign(account, sha256(binary))

    %{
      type: "liquidityWithdrawal",
      pinHeight: ctx.chain_pin.pin_height,
      nonceId: ctx.nonce_id.value,
      feeE8: ctx.fee.e8,
      assetHash: asset_hash,
      amountE8: units.e8,
      signature65: sig
    }
  end

  @doc """
  Build and sign a cancelation transaction (cancel a pending limit order).
  """
  @spec cancel_transaction(t(), Account.t(), non_neg_integer(), NonceId.t()) :: transaction()
  def cancel_transaction(
        %TransactionContext{} = ctx,
        %Account{} = account,
        cancel_height,
        %NonceId{} = cancel_nonce_id
      )
      when is_integer(cancel_height) and cancel_height >= 0 do
    binary =
      bin(ctx.chain_pin.pin_hash) <>
        u32be(ctx.chain_pin.pin_height) <>
        u32be(ctx.nonce_id.value) <>
        <<0, 0, 0>> <>
        u64be(ctx.fee.e8) <>
        u32be(cancel_height) <>
        u32be(cancel_nonce_id.value)

    {:ok, {_r, _s, _recid, sig}} = Account.sign(account, sha256(binary))

    %{
      type: "cancelation",
      pinHeight: ctx.chain_pin.pin_height,
      nonceId: ctx.nonce_id.value,
      feeE8: ctx.fee.e8,
      cancelHeight: cancel_height,
      cancelNonceId: cancel_nonce_id.value,
      signature65: sig
    }
  end

  @doc """
  Build and sign an asset creation transaction.

  The `name` is truncated/padded to 5 ASCII bytes.
  """
  @spec create_assets(t(), Account.t(), Funds.t(), TokenDecimals.t(), String.t()) :: transaction()
  def create_assets(
        %TransactionContext{} = ctx,
        %Account{} = account,
        %Funds{} = total_supply,
        %TokenDecimals{} = decimals,
        name
      )
      when is_binary(name) do
    name_buffer = name_pad5(name)

    binary =
      bin(ctx.chain_pin.pin_hash) <>
        u32be(ctx.chain_pin.pin_height) <>
        u32be(ctx.nonce_id.value) <>
        <<0, 0, 0>> <>
        u64be(ctx.fee.e8) <>
        u64be(total_supply.amount) <>
        <<decimals.decimals>> <>
        name_buffer

    {:ok, {_r, _s, _recid, sig}} = Account.sign(account, sha256(binary))

    %{
      type: "assetCreation",
      pinHeight: ctx.chain_pin.pin_height,
      nonceId: ctx.nonce_id.value,
      feeE8: ctx.fee.e8,
      supplyU64: total_supply.amount,
      decimals: decimals.decimals,
      name: name,
      signature65: sig
    }
  end

  defp bin(hex) when is_binary(hex), do: Base.decode16!(hex, case: :mixed)

  defp u32be(value) when is_integer(value) and value >= 0 and value <= 0xFFFFFFFF do
    <<value::big-32>>
  end

  defp u64be(value) when is_integer(value) and value >= 0 do
    <<value::big-64>>
  end

  defp address_bytes(address) when is_binary(address) do
    <<raw::binary-size(40), _checksum::binary-size(8)>> = address
    Base.decode16!(raw, case: :mixed)
  end

  defp sha256(data), do: :crypto.hash(:sha256, data)

  defp name_pad5(name) do
    padded = name <> <<0, 0, 0, 0, 0>>
    <<raw::binary-size(5), _::binary>> = padded
    raw
  end
end
