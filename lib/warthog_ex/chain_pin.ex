defmodule WarthogEx.ChainPin do
  @moduledoc """
  A proposed chain pin: the `(height, hash)` pair that transactions are built
  against.

  Pin heights are always multiples of #{32}: a block body stores a 1-byte
  *relative* pin and the absolute height is `relativePin << 5`, so at most 256
  distinct pins exist in a chain. `core/defi`'s `PinHeight` type rejects any
  height that is not one of them.

  A pin is not a single permanent thing. The chain advances through a sequence
  of them, each at a height >= the last. `/chain/head` reports the most recently
  proposed one, which is what a client needs in order to build a valid
  transaction.

  ## Example

      iex> {:ok, pin} = WarthogEx.ChainPin.parse(%{"pinHash" => String.duplicate("a", 64), "pinHeight" => 320}, :v1)
      iex> pin.pin_height
      320
  """

  alias WarthogEx.ChainPin

  @type t :: %__MODULE__{pin_hash: String.t(), pin_height: non_neg_integer()}

  defstruct pin_hash: nil, pin_height: nil

  @pin_height_multiple 32

  @doc """
  Pin heights are always multiples of 32 (1-byte relative pin).
  """
  @spec pin_height_multiple() :: pos_integer()
  def pin_height_multiple, do: @pin_height_multiple

  @doc """
  Check that a pair of raw values forms a well-formed pin.
  """
  @spec validate(term(), term()) :: boolean()
  def validate(pin_hash, pin_height) when is_binary(pin_hash) and is_integer(pin_height) do
    byte_size(pin_hash) == 64 and pin_height >= 0 and
      rem(pin_height, @pin_height_multiple) == 0
  end

  def validate(_pin_hash, _pin_height), do: false

  @doc """
  Extract the pin from a `/chain/head` payload.

  Reads the fields according to the API generation the payload came from.

  Returns `{:ok, %ChainPin{}}` if the payload matches `version`, otherwise
  `:error`.
  """
  @spec parse(map(), WarthogEx.api_version()) :: {:ok, t()} | :error
  def parse(data, version) when is_map(data) and version in [:v1, :v2] do
    case chain_head_source(data, version) do
      %{"pinHash" => pin_hash, "pinHeight" => pin_height} ->
        if validate(pin_hash, pin_height) do
          {:ok, %ChainPin{pin_hash: pin_hash, pin_height: pin_height}}
        else
          :error
        end

      _ ->
        :error
    end
  end

  def parse(_data, _version), do: :error

  @doc """
  Like `parse/2` but raises on invalid input.
  """
  @spec parse!(map(), WarthogEx.api_version()) :: t()
  def parse!(data, version) do
    case parse(data, version) do
      {:ok, pin} ->
        pin

      :error ->
        raise ArgumentError, "invalid #{version} chain head response"
    end
  end

  @doc """
  Locate the ChainHead fields within a `/chain/head` payload for a given API
  generation.

  Both generations serialize the same C++ type, `Head { ChainHead chainHead;
  bool synced; }`. V1 (`core/master`, `core/dev`) uses a hand-written
  `to_json(API::Head&)` that flattens ChainHead into the top level; V2
  (`core/defi`) uses glaze, which reflects the nesting automatically.

  Returns the ChainHead fields, or `:error` when the payload is not the expected
  shape.
  """
  @spec chain_head_source(term(), WarthogEx.api_version()) :: map() | :error
  def chain_head_source(data, version) when is_map(data) and version in [:v1, :v2] do
    # V1 puts the fields at the top level; V2 wraps them in `chainHead`.
    src =
      case version do
        :v1 -> data
        :v2 -> Map.get(data, "chainHead")
      end

    if is_map(src), do: src, else: :error
  end

  def chain_head_source(_data, _version), do: :error
end