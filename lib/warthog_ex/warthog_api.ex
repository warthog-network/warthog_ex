defmodule WarthogEx.WarthogApi do
  @moduledoc """
  Client for communicating with Warthog nodes.

  The default `base_url` is the first entry in `@known_nodes` (a public
  testnet node). Override it for a local dev node:

      # public testnet (default)
      iex> api = WarthogEx.WarthogApi.new()

      # local dev
      iex> api = WarthogEx.WarthogApi.new("http://127.0.0.1:3100")
  """

  alias Jason.Encoder
  alias WarthogEx.NonceId
  alias WarthogEx.RoundedFee
  alias WarthogEx.TransactionContext
  alias WarthogEx.WarthogApi

  require Logger

  @known_nodes [
    "http://65.87.7.86:3001",
    "http://185.209.228.16:3001",
    "http://89.117.150.162:3001",
    "http://62.72.44.89:3001",
    "http://217.182.64.43:3001",
    "https://node.wartscan.io",
    "http://dev.node-s.com:3001"
  ]

  @type node_url :: String.t()

  @type api_success(t) :: {:ok, t}
  @type api_error :: {:error, code: integer(), error: String.t()}

  @type chain_head_data :: %{chainHead: %{pinHash: String.t(), pinHeight: non_neg_integer()}}
  @type submit_transaction_data :: %{txHash: String.t()}

  defstruct base_url: hd(@known_nodes)

  @type t :: %__MODULE__{base_url: String.t()}

  @doc """
  Known Warthog public nodes (best-effort, may include dead nodes).
  """
  @spec known_nodes() :: [node_url()]
  def known_nodes, do: @known_nodes

  @doc """
  Create a new API client. Defaults to the first `known_nodes/0` entry
  (public testnet); pass an explicit URL for a local dev node.
  """
  @spec new() :: t()
  @spec new(node_url()) :: t()
  def new(base_url \\ hd(@known_nodes)) when is_binary(base_url) do
    %WarthogApi{base_url: base_url}
  end

  @doc """
  Get the current chain head (latest pinned block).
  """
  @spec get_chain_head(t()) :: api_success(chain_head_data()) | api_error()
  def get_chain_head(%WarthogApi{} = api) do
    request(api, "/chain/head")
  end

  @doc """
  Submit a signed transaction to the node.
  """
  @spec submit_transaction(t(), TransactionContext.transaction()) ::
          api_success(submit_transaction_data()) | api_error()
  def submit_transaction(%WarthogApi{} = api, tx) do
    request(api, "/transaction/add", method: :post, body: tx)
  end

  @doc """
  Fetch the chain head and build a `TransactionContext`.

  Raises on error.
  """
  @spec create_transaction_context(t(), RoundedFee.t(), NonceId.t()) ::
          {:ok, TransactionContext.t()} | api_error()
  def create_transaction_context(%WarthogApi{} = api, %RoundedFee{} = fee, %NonceId{} = nonce_id) do
    case get_chain_head(api) do
      {:ok, %{"chainHead" => %{"pinHash" => pin_hash, "pinHeight" => pin_height}}} ->
        {:ok,
         TransactionContext.new(%{pin_hash: pin_hash, pin_height: pin_height}, fee, nonce_id)}

      {:error, _} = err ->
        err
    end
  end

  defp request(%WarthogApi{base_url: base_url}, path, opts \\ []) do
    url = base_url <> path
    method = Keyword.get(opts, :method, :get)
    body = Keyword.get(opts, :body)
    query = Keyword.get(opts, :query, %{})

    full_url =
      case map_size(query) do
        0 -> url
        _ -> url <> "?" <> URI.encode_query(query)
      end

    req_opts =
      [
        method: method,
        decode_body: false,
        receive_timeout: 30_000
      ] ++
        if(body, do: [json: encode_body(body)], else: [])

    case Req.request([url: full_url] ++ req_opts) do
      {:ok, %Req.Response{status: status, body: raw_body}} when status in 200..299 ->
        case Jason.decode(raw_body) do
          {:ok, %{"code" => 0, "data" => data}} ->
            {:ok, data}

          {:ok, %{"code" => code, "error" => error}} when is_integer(code) ->
            {:error, code: code, error: error || "Unknown error"}

          {:ok, %{"code" => code}} when is_integer(code) ->
            {:error, code: code, error: "Unknown error"}

          {:ok, other} ->
            {:error, code: -1, error: "Unexpected response: #{inspect(other)}"}

          {:error, %Jason.DecodeError{} = e} ->
            {:error, code: -1, error: "Invalid JSON: #{Exception.message(e)}"}
        end

      {:ok, %Req.Response{status: status, body: raw_body}} ->
        {:error, code: status, error: raw_body || "HTTP #{status}"}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, code: -1, error: "Transport error: #{inspect(reason)}"}
    end
  end

  defp encode_body(body), do: Encoder.encode(body, %{})
end
