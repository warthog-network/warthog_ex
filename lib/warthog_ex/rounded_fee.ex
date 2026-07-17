defmodule WarthogEx.RoundedFee do
  @moduledoc """
  Transaction fee in rounded WART format (64-bit WART scale).

  This is NOT the 16-bit compact representation itself. Instead it is the
  result of converting WART to a `CompactFee` and then back to the WART
  scale. This is a lossy operation: the original WART value cannot be
  restored from a `RoundedFee`. Warthog nodes require rounded values on the
  64-bit WART scale in API calls.
  """

  alias WarthogEx.CompactFee
  alias WarthogEx.RoundedFee
  alias WarthogEx.Wart

  defstruct [:e8]

  @type t :: %__MODULE__{e8: non_neg_integer()}

  @doc """
  Create a `RoundedFee` from a `Wart` amount. Pass `ceil: true` to round up,
  `ceil: false` to round down.
  """
  @spec from_wart(Wart.t(), boolean()) :: t()
  def from_wart(%Wart{} = wart, ceil?) when is_boolean(ceil?) do
    compact = CompactFee.from_wart(wart, ceil?)
    rounded = CompactFee.to_wart(compact)
    %RoundedFee{e8: rounded.e8}
  end

  @doc """
  Create a `RoundedFee` from a raw E8 value.

  Returns `{:ok, %RoundedFee{}}` if the value fits in a 64-bit unsigned
  integer, otherwise `:error`.
  """
  @spec from_e8(non_neg_integer(), boolean()) :: {:ok, t()} | :error
  def from_e8(e8, ceil?) when is_integer(e8) and e8 >= 0 and is_boolean(ceil?) do
    with {:ok, wart} <- Wart.from_e8(e8) do
      {:ok, from_wart(wart, ceil?)}
    end
  end

  def from_e8(_, _), do: :error

  @doc """
  Like `from_e8/2` but raises on invalid input.
  """
  @spec from_e8!(integer(), boolean()) :: t()
  def from_e8!(e8, ceil?) do
    case from_e8(e8, ceil?) do
      {:ok, fee} -> fee
      :error -> raise ArgumentError, "invalid E8 for RoundedFee: #{inspect(e8)}"
    end
  end

  @doc """
  Get the minimum possible fee (`0.00000001` WART = `1` E8).
  """
  @spec min() :: t()
  def min do
    {:ok, fee} = from_e8(0, false)
    fee
  end

  @doc """
  Convert a `RoundedFee` to a `Wart`.
  """
  @spec to_wart(t()) :: Wart.t()
  def to_wart(%RoundedFee{e8: e8}) do
    {:ok, w} = Wart.from_e8(e8)
    w
  end
end
