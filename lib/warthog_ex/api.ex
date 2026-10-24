defmodule WarthogEx.Api do
  @moduledoc """
  Shared HTTP plumbing for the node clients.

  The two node families are separate APIs, so they get a client each:
  `WarthogEx.LegacyApi` for the legacy node (core/master, core/dev) and
  `WarthogEx.DeFiApi` for the DeFi node (core/defi). What they genuinely
  share lives here: the request plumbing, the chain head fetch and the
  transaction submission.
  """

  alias Jason.Encoder
  alias WarthogEx.Api
  alias WarthogEx.ChainHead

  require Logger

  @known_nodes_legacy [
    "http://65.87.7.86:3001",
    "http://185.209.228.16:3001",
    "http://89.117.150.162:3001",
    "http://62.72.44.89:3001",
    "http://217.182.64.43:3001",
    "https://node.wartscan.io",
    "http://dev.node-s.com:3001"
  ]

  @known_nodes_defi [
    "http://65.87.7.86:3002/",
    "https://warthog-defitestnet.duckdns.org/",
    "http://104.251.219.14:3001/",
    "http://85.56.145.106:3001/",
    "http://64.44.90.170:3001/"
  ]

  defstruct [:base_url]

  @type t :: %__MODULE__{base_url: String.t()}

  @type api_success(t) :: {:ok, t}
  @type api_error :: {:error, code: integer(), error: String.t()}

  @doc """
  Known legacy nodes (core/master, core/dev).

  These serve the V1 API generation.
  """
  @spec known_nodes_legacy() :: [String.t()]
  def known_nodes_legacy, do: @known_nodes_legacy

  @doc """
  Known DeFi nodes (core/defi).

  These serve the V2 API generation.
  """
  @spec known_nodes_defi() :: [String.t()]
  def known_nodes_defi, do: @known_nodes_defi

  @doc """
  Fetch the chain head and normalize it for the given generation.

  The V1 and V2 payload shapes are not interchangeable, so the caller says
  which one it expects.
  """
  @spec get_chain_head(t(), WarthogEx.api_version()) :: api_success(ChainHead.t()) | api_error()
  def get_chain_head(%Api{} = api, version) do
    with {:ok, data} <- request(api, "/chain/head") do
      case ChainHead.parse(data, version) do
        {:ok, head} ->
          {:ok, head}

        :error ->
          {:error, code: -1, error: "Invalid #{version} chain head response"}
      end
    end
  end

  @doc """
  Submit a signed transaction to the node.

  The node answers with `{"code": 0, "data": {"txHash": "..."}}`. The hash is
  checked rather than assumed, so a response that does not carry one is
  reported as an error instead of being passed off as a success.
  """
  @spec submit_transaction(t(), map()) :: api_success(%{String.t() => term()}) | api_error()
  def submit_transaction(%Api{} = api, tx) do
    with {:ok, data} <- request(api, "/transaction/add", method: :post, body: tx) do
      case data do
        %{"txHash" => tx_hash} when is_binary(tx_hash) ->
          {:ok, %{"txHash" => tx_hash}}

        _ ->
          {:error, code: -1, error: "Invalid transaction add response"}
      end
    end
  end

  @doc """
  Perform a request against the node API.

  The response envelope is `{"code": 0, "data": ...}` on success and
  `{"code": <n>, "error": "..."}` on failure.
  """
  @spec request(t(), String.t(), keyword()) :: {:ok, term()} | api_error()
  def request(%Api{base_url: base_url}, path, opts \\ []) do
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
