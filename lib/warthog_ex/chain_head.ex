defmodule WarthogEx.ChainHead do
  @moduledoc """
  A node's view of the chain head, normalized across API generations.

  V1 returns these fields flat and V2 nests them under `chainHead`; this always
  exposes them in one shape. See `WarthogEx.api_version/0`.

  ## Example

      iex> head = WarthogEx.ChainHead.parse!(%{
      ...>   "hash" => String.duplicate("a", 64),
      ...>   "height" => 100,
      ...>   "pinHash" => String.duplicate("a", 64),
      ...>   "pinHeight" => 64,
      ...>   "synced" => true
      ...> }, :v1)
      iex> {head.height, head.synced}
      {100, true}
  """

  alias WarthogEx.ChainHead
  alias WarthogEx.ChainPin

  @type t :: %__MODULE__{
          pin: ChainPin.t(),
          hash: String.t(),
          height: non_neg_integer(),
          synced: boolean()
        }

  defstruct [:pin, :hash, :height, synced: false]

  @doc """
  Extract the chain head from a `/chain/head` payload.

  Reads the fields according to the API generation the payload came from.

  Returns `{:ok, %ChainHead{}}` if the payload matches `version`, otherwise
  `:error`.
  """
  @spec parse(term(), WarthogEx.api_version()) :: {:ok, t()} | :error
  def parse(data, version) when is_map(data) and version in [:v1, :v2] do
    with {:ok, pin} <- ChainPin.parse(data, version),
         {:ok, src} <- chain_head_source(data, version),
         %{"hash" => hash} when is_binary(hash) <- src,
         %{"height" => height} when is_integer(height) and height >= 0 <- src do
      # `synced` sits at the root of the payload in both generations.
      {:ok, %ChainHead{pin: pin, hash: hash, height: height, synced: synced?(data)}}
    else
      _ -> :error
    end
  end

  def parse(_data, _version), do: :error

  @doc """
  Like `parse/2` but raises on invalid input.
  """
  @spec parse!(term(), WarthogEx.api_version()) :: t()
  def parse!(data, version) do
    case parse(data, version) do
      {:ok, head} ->
        head

      :error ->
        raise ArgumentError, "invalid #{version} chain head response"
    end
  end

  defp chain_head_source(data, version) do
    case ChainPin.chain_head_source(data, version) do
      %{} = src -> {:ok, src}
      :error -> :error
    end
  end

  defp synced?(data), do: Map.get(data, "synced") == true
end