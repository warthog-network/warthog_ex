defmodule WarthogEx.DeFiApi do
  @moduledoc """
  Client for the DeFi node (core/defi).

  That node speaks the V2 API generation: the chain head comes back nested
  under `chainHead`, and it accepts nine kinds of transaction.

      # public DeFi node, V2 API (default URL)
      iex> api = WarthogEx.DeFiApi.new()

      # local dev node, V2 API
      iex> api = WarthogEx.DeFiApi.new("http://127.0.0.1:3101")
  """

  alias WarthogEx.Api
  alias WarthogEx.ChainHead
  alias WarthogEx.DeFiTransactionContext
  alias WarthogEx.DeFiWartBalance
  alias WarthogEx.NonceId
  alias WarthogEx.RoundedFee
  alias WarthogEx.TokenBalance

  @doc """
  Create a new client.

  `base_url` defaults to the first known DeFi node.
  """
  @spec new() :: Api.t()
  @spec new(String.t()) :: Api.t()
  def new(base_url \\ hd(Api.known_nodes_defi())), do: %Api{base_url: base_url}

  @doc """
  Get the current chain head.
  """
  @spec get_chain_head(Api.t()) :: Api.api_success(ChainHead.t()) | Api.api_error()
  def get_chain_head(api), do: Api.get_chain_head(api, :v2)

  @doc """
  Fetch the chain head and build a `DeFiTransactionContext`.

  Raises on error.
  """
  @spec create_transaction_context(Api.t(), RoundedFee.t(), NonceId.t()) ::
          {:ok, DeFiTransactionContext.t()} | Api.api_error()
  def create_transaction_context(%Api{} = api, %RoundedFee{} = fee, %NonceId{} = nonce_id) do
    with {:ok, head} <- get_chain_head(api) do
      {:ok, DeFiTransactionContext.new(head.pin, fee, nonce_id)}
    end
  end

  @doc """
  Submit a signed transaction to the node.
  """
  @spec submit_transaction(Api.t(), map()) :: Api.api_success(map()) | Api.api_error()
  def submit_transaction(api, tx), do: Api.submit_transaction(api, tx)

  @doc """
  Get the WART balance of an account.

  The DeFi node reports the balance three ways: what the account owns, what
  is locked in open limit orders, and what is locked by transactions in the
  mempool.
  """
  @spec get_wart_balance(Api.t(), String.t()) :: Api.api_success(DeFiWartBalance.t()) | Api.api_error()
  def get_wart_balance(%Api{} = api, address) do
    with {:ok, data} <- Api.request(api, "/account/#{address}/wart_balance") do
      case DeFiWartBalance.parse(data) do
        {:ok, balance} -> {:ok, balance}
        :error -> {:error, code: -1, error: "Invalid balance response"}
      end
    end
  end

  @doc """
  Get the balance of a token an account holds.
  """
  @spec get_token_balance(Api.t(), String.t(), String.t()) ::
          Api.api_success(TokenBalance.t()) | Api.api_error()
  def get_token_balance(%Api{} = api, address, asset_hash) do
    hash = asset_hash |> String.replace(~r/^0x/i, "") |> String.downcase()

    with {:ok, data} <- Api.request(api, "/account/#{address}/balance/asset:#{hash}") do
      case TokenBalance.parse(data) do
        {:ok, balance} -> {:ok, balance}
        :error -> {:error, code: -1, error: "Invalid balance response"}
      end
    end
  end
end
