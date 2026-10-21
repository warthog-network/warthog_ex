defmodule WarthogEx.DeFiTransactionContext do
  @moduledoc """
  Transaction builder for the DeFi node (core/defi).

  That node accepts nine kinds of transaction, so this context has all nine
  builders. Its WART transfer reads the amount from `wartE8`, which is where
  the DeFi node looks for it; `amountE8` means the liquidity share count on
  that node.

  Obtained via `WarthogEx.DeFiApi.create_transaction_context/3`.

  All properties (`chain_pin`, `fee`, `nonce_id`) can be modified. When
  reusing this context for multiple transactions, you MUST change the
  `nonce_id` for each new transaction to prevent nonce collisions. The
  `chain_pin` should typically remain unchanged unless you need to refresh it
  from the network.
  """

  alias WarthogEx.Account
  alias WarthogEx.Address
  alias WarthogEx.ChainPin
  alias WarthogEx.Funds
  alias WarthogEx.Liquidity
  alias WarthogEx.NonceId
  alias WarthogEx.Price
  alias WarthogEx.RoundedFee
  alias WarthogEx.TokenDecimals
  alias WarthogEx.TransactionBytes
  alias WarthogEx.Wart

  defstruct [:chain_pin, :fee, :nonce_id]

  @type t :: %__MODULE__{
          chain_pin: ChainPin.t(),
          fee: RoundedFee.t(),
          nonce_id: NonceId.t()
        }

  @doc """
  Create a new transaction context.
  """
  @spec new(ChainPin.t(), RoundedFee.t(), NonceId.t()) :: t()
  def new(%ChainPin{} = chain_pin, %RoundedFee{} = fee, %NonceId{} = nonce_id) do
    %__MODULE__{chain_pin: chain_pin, fee: fee, nonce_id: nonce_id}
  end

  defimpl WarthogEx.TransactionContext do
    alias WarthogEx.Account
    alias WarthogEx.Address
    alias WarthogEx.TransactionBytes
    alias WarthogEx.Wart

    @doc """
    Build and sign a native WART transfer transaction.
    """
    def transfer_wart(ctx, %Account{} = account, %Address{} = to_addr, %Wart{} = wart) do
      binary =
        TransactionBytes.wart_transfer_bytes(
          ctx.chain_pin,
          ctx.fee,
          ctx.nonce_id,
          to_addr,
          wart
        )

      {:ok, {_r, _s, _recid, sig}} = Account.sign_bytes(account, binary)

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
  end

  @doc """
  Build and sign an asset transfer transaction.
  """
  @spec transfer_asset(t(), Account.t(), String.t(), Address.t(), Funds.t()) :: map()
  def transfer_asset(
        %__MODULE__{} = ctx,
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
  @spec transfer_liquidity(t(), Account.t(), String.t(), Address.t(), Liquidity.t()) :: map()
  def transfer_liquidity(
        %__MODULE__{} = ctx,
        %Account{} = account,
        asset_hash,
        %Address{} = to_addr,
        %Liquidity{} = units
      ) do
    token_transfer_internal(ctx, account, asset_hash, true, to_addr, units.e8)
  end

  defp token_transfer_internal(ctx, account, asset_hash, is_liquidity, to_addr, amount_e8) do
    binary =
      TransactionBytes.bin(ctx.chain_pin.pin_hash) <>
        TransactionBytes.u32be(ctx.chain_pin.pin_height) <>
        TransactionBytes.u32be(ctx.nonce_id.value) <>
        <<0, 0, 0>> <>
        TransactionBytes.u64be(ctx.fee.e8) <>
        TransactionBytes.bin(asset_hash) <>
        <<if(is_liquidity, do: 1, else: 0)>> <>
        TransactionBytes.address_bytes(to_addr.hex) <>
        TransactionBytes.u64be(amount_e8)

    {:ok, {_r, _s, _recid, sig}} = Account.sign_bytes(account, binary)

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
  @spec buy(t(), Account.t(), String.t(), Wart.t(), Price.t()) :: map()
  def buy(
        %__MODULE__{} = ctx,
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
  @spec sell(t(), Account.t(), String.t(), Funds.t(), Price.t()) :: map()
  def sell(
        %__MODULE__{} = ctx,
        %Account{} = account,
        asset_hash,
        %Funds{amount: token_amount},
        %Price{} = limit
      ) do
    limit_swap_internal(ctx, account, asset_hash, false, token_amount, limit)
  end

  defp limit_swap_internal(ctx, account, asset_hash, is_buy, amount_e8, limit) do
    binary =
      TransactionBytes.bin(ctx.chain_pin.pin_hash) <>
        TransactionBytes.u32be(ctx.chain_pin.pin_height) <>
        TransactionBytes.u32be(ctx.nonce_id.value) <>
        <<0, 0, 0>> <>
        TransactionBytes.u64be(ctx.fee.e8) <>
        TransactionBytes.bin(asset_hash) <>
        <<if(is_buy, do: 1, else: 0)>> <>
        TransactionBytes.u64be(amount_e8) <>
        TransactionBytes.bin(Price.to_hex(limit))

    {:ok, {_r, _s, _recid, sig}} = Account.sign_bytes(account, binary)

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

  The amount is the token amount, which the DeFi node reads from `amountU64`.
  The liquidity share count is what a withdrawal carries, in `amountE8`.
  """
  @spec deposit_liquidity(t(), Account.t(), String.t(), Funds.t(), Wart.t()) :: map()
  def deposit_liquidity(
        %__MODULE__{} = ctx,
        %Account{} = account,
        asset_hash,
        %Funds{} = token_amount,
        %Wart{} = wart
      ) do
    binary =
      TransactionBytes.bin(ctx.chain_pin.pin_hash) <>
        TransactionBytes.u32be(ctx.chain_pin.pin_height) <>
        TransactionBytes.u32be(ctx.nonce_id.value) <>
        <<0, 0, 0>> <>
        TransactionBytes.u64be(ctx.fee.e8) <>
        TransactionBytes.bin(asset_hash) <>
        TransactionBytes.u64be(token_amount.amount) <>
        TransactionBytes.u64be(wart.e8)

    {:ok, {_r, _s, _recid, sig}} = Account.sign_bytes(account, binary)

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

  The amount is the liquidity share count, which the DeFi node reads from
  `amountE8`.
  """
  @spec withdraw_liquidity(t(), Account.t(), String.t(), Liquidity.t()) :: map()
  def withdraw_liquidity(
        %__MODULE__{} = ctx,
        %Account{} = account,
        asset_hash,
        %Liquidity{} = units
      ) do
    binary =
      TransactionBytes.bin(ctx.chain_pin.pin_hash) <>
        TransactionBytes.u32be(ctx.chain_pin.pin_height) <>
        TransactionBytes.u32be(ctx.nonce_id.value) <>
        <<0, 0, 0>> <>
        TransactionBytes.u64be(ctx.fee.e8) <>
        TransactionBytes.bin(asset_hash) <>
        TransactionBytes.u64be(units.e8)

    {:ok, {_r, _s, _recid, sig}} = Account.sign_bytes(account, binary)

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
  @spec cancel_transaction(t(), Account.t(), non_neg_integer(), NonceId.t()) :: map()
  def cancel_transaction(
        %__MODULE__{} = ctx,
        %Account{} = account,
        cancel_height,
        %NonceId{} = cancel_nonce_id
      )
      when is_integer(cancel_height) and cancel_height >= 0 do
    binary =
      TransactionBytes.bin(ctx.chain_pin.pin_hash) <>
        TransactionBytes.u32be(ctx.chain_pin.pin_height) <>
        TransactionBytes.u32be(ctx.nonce_id.value) <>
        <<0, 0, 0>> <>
        TransactionBytes.u64be(ctx.fee.e8) <>
        TransactionBytes.u32be(cancel_height) <>
        TransactionBytes.u32be(cancel_nonce_id.value)

    {:ok, {_r, _s, _recid, sig}} = Account.sign_bytes(account, binary)

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
  @spec create_assets(t(), Account.t(), Funds.t(), TokenDecimals.t(), String.t()) :: map()
  def create_assets(
        %__MODULE__{} = ctx,
        %Account{} = account,
        %Funds{} = total_supply,
        %TokenDecimals{} = decimals,
        name
      )
      when is_binary(name) do
    name_buffer = name_pad5(name)

    binary =
      TransactionBytes.bin(ctx.chain_pin.pin_hash) <>
        TransactionBytes.u32be(ctx.chain_pin.pin_height) <>
        TransactionBytes.u32be(ctx.nonce_id.value) <>
        <<0, 0, 0>> <>
        TransactionBytes.u64be(ctx.fee.e8) <>
        TransactionBytes.u64be(total_supply.amount) <>
        <<decimals.decimals>> <>
        name_buffer

    {:ok, {_r, _s, _recid, sig}} = Account.sign_bytes(account, binary)

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

  defp name_pad5(name) do
    padded = name <> <<0, 0, 0, 0, 0>>
    <<raw::binary-size(5), _::binary>> = padded
    raw
  end
end
