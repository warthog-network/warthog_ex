defmodule WarthogEx.LegacyApi do
  @moduledoc """
  Client for the legacy node (core/master, core/dev).

  That node speaks the V1 API generation: the chain head comes back flat,
  and it accepts one kind of transaction, a transfer.

  The first known legacy node is a public **main net** node (port 3001):

      # public main net, V1 API (default URL)
      iex> api = WarthogEx.LegacyApi.new()

      # local dev node, V1 API
      iex> api = WarthogEx.LegacyApi.new("http://127.0.0.1:3100")
  """

  alias WarthogEx.Api
  alias WarthogEx.ChainHead
  alias WarthogEx.LegacyTransactionContext
  alias WarthogEx.NonceId
  alias WarthogEx.RoundedFee
  alias WarthogEx.Wart

  @doc """
  Create a new client.

  `base_url` defaults to the first known legacy node.
  """
  @spec new() :: Api.t()
  @spec new(String.t()) :: Api.t()
  def new(base_url \\ hd(Api.known_nodes_legacy())), do: %Api{base_url: base_url}

  @doc """
  Get the current chain head.
  """
  @spec get_chain_head(Api.t()) :: Api.api_success(ChainHead.t()) | Api.api_error()
  def get_chain_head(api), do: Api.get_chain_head(api, :v1)

  @doc """
  Fetch the chain head and build a `LegacyTransactionContext`.

  Raises on error.
  """
  @spec create_transaction_context(Api.t(), RoundedFee.t(), NonceId.t()) ::
          {:ok, LegacyTransactionContext.t()} | Api.api_error()
  def create_transaction_context(%Api{} = api, %RoundedFee{} = fee, %NonceId{} = nonce_id) do
    with {:ok, head} <- get_chain_head(api) do
      {:ok, LegacyTransactionContext.new(head.pin, fee, nonce_id)}
    end
  end

  @doc """
  Submit a signed transaction to the node.
  """
  @spec submit_transaction(Api.t(), map()) :: Api.api_success(map()) | Api.api_error()
  def submit_transaction(api, tx), do: Api.submit_transaction(api, tx)

  @doc """
  Get the version of the node.

  The legacy node serves it on `/tools/version`.
  """
  @spec get_node_version(Api.t()) :: Api.api_success(WarthogEx.NodeVersion.t()) | Api.api_error()
  def get_node_version(%Api{} = api) do
    Api.get_node_version(api, "/tools/version")
  end

  @doc """
  Get the WART balance of an account.

  The legacy node reports one number: the confirmed balance. It has no limit
  orders, and it does not report what pending transactions lock, so there is
  no split to make.
  """
  @spec get_wart_balance(Api.t(), String.t()) :: Api.api_success(Wart.t()) | Api.api_error()
  def get_wart_balance(%Api{} = api, address) do
    with {:ok, data} <- Api.request(api, "/account/#{address}/balance") do
      case data do
        %{"balance" => balance} when is_binary(balance) ->
          case Wart.parse(balance) do
            {:ok, wart} -> {:ok, wart}
            :error -> {:error, code: -1, error: "Invalid balance response"}
          end

        _ ->
          {:error, code: -1, error: "Invalid balance response"}
      end
    end
  end
end
