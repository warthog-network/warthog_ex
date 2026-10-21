defmodule WarthogEx.LegacyTransactionContext do
  @moduledoc """
  Transaction builder for the legacy node (core/master, core/dev).

  That node accepts one kind of transaction, a transfer, so this context
  offers one builder. The legacy node reads the amount from `amountE8`; the
  DeFi node reads it from `wartE8` and never looks at `amountE8`, where that
  name means the liquidity share count instead.

  Obtained via `WarthogEx.LegacyApi.create_transaction_context/3`.

  All properties (`chain_pin`, `fee`, `nonce_id`) can be modified. When
  reusing this context for multiple transactions, you MUST change the
  `nonce_id` for each new transaction to prevent nonce collisions. The
  `chain_pin` should typically remain unchanged unless you need to refresh it
  from the network.
  """

  alias WarthogEx.ChainPin
  alias WarthogEx.NonceId
  alias WarthogEx.RoundedFee

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

    The payload carries no `type`. The legacy node has a single transaction
    endpoint that parses one message shape, a transfer, so it never looks at
    a type.
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
        pinHeight: ctx.chain_pin.pin_height,
        nonceId: ctx.nonce_id.value,
        feeE8: ctx.fee.e8,
        toAddr: to_addr.hex,
        amountE8: wart.e8,
        signature65: sig
      }
    end
  end
end
