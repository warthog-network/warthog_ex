defmodule WarthogEx.Wart do
  @moduledoc """
  Warthog's native token (WART) with 8 decimal places.

  `1 WART = 100_000_000 E8`.

  ## Example

      iex> {:ok, w} = WarthogEx.Wart.parse(\"1.5\")
      iex> w.e8
      150000000
  """

  alias WarthogEx.Funds
  alias WarthogEx.ParsedFunds
  alias WarthogEx.RoundedFee
  alias WarthogEx.TokenDecimals
  alias WarthogEx.Wart

  defstruct [:e8]

  @type t :: %__MODULE__{e8: non_neg_integer()}

  @doc """
  Parse a decimal string to `Wart`.

  Returns `{:ok, %Wart{}}` if valid, otherwise `:error`.
  """
  @spec parse(String.t()) :: {:ok, t()} | :error
  def parse(string) when is_binary(string) do
    with {:ok, parsed} <- ParsedFunds.parse(string),
         {:ok, value} <- value_from(parsed) do
      {:ok, %Wart{e8: value}}
    end
  end

  def parse(_), do: :error

  @doc """
  Like `parse/1` but raises on invalid input.
  """
  @spec parse!(String.t()) :: t()
  def parse!(string) do
    case parse(string) do
      {:ok, wart} -> wart
      :error -> raise ArgumentError, "invalid WART string: #{inspect(string)}"
    end
  end

  @doc """
  Convert a `ParsedFunds` into `Wart`.

  Returns `{:ok, %Wart{}}` if valid, otherwise `:error`.
  """
  @spec from_parsed_funds(ParsedFunds.t()) :: {:ok, t()} | :error
  def from_parsed_funds(%ParsedFunds{} = parsed) do
    case value_from(parsed) do
      {:ok, value} -> {:ok, %Wart{e8: value}}
      :error -> :error
    end
  end

  @doc """
  Like `from_parsed_funds/1` but raises on invalid input.
  """
  @spec from_parsed_funds!(ParsedFunds.t()) :: t()
  def from_parsed_funds!(parsed) do
    case from_parsed_funds(parsed) do
      {:ok, wart} -> wart
      :error -> raise ArgumentError, "invalid parsed funds for WART"
    end
  end

  @doc """
  Create `Wart` from a raw E8 value.

  Returns `{:ok, %Wart{}}` if the value is in `[0, MAX_U64]`, otherwise
  `:error`.
  """
  @spec from_e8(integer()) :: {:ok, t()} | :error
  def from_e8(e8) when is_integer(e8) and e8 >= 0 do
    if e8 > WarthogEx.max_u64() do
      :error
    else
      {:ok, %Wart{e8: e8}}
    end
  end

  def from_e8(_), do: :error

  @doc """
  Like `from_e8/1` but raises on invalid input.
  """
  @spec from_e8!(integer()) :: t()
  def from_e8!(e8) do
    case from_e8(e8) do
      {:ok, wart} -> wart
      :error -> raise ArgumentError, "invalid E8: #{inspect(e8)} (must be 0..0xFFFFFFFFFFFFFFFF)"
    end
  end

  @doc """
  Convert to a `RoundedFee`. Pass `ceil: true` to round up, `ceil: false` to
  round down.
  """
  @spec rounded_fee(t(), boolean()) :: RoundedFee.t()
  def rounded_fee(%Wart{} = wart, ceil?) when is_boolean(ceil?) do
    RoundedFee.from_wart(wart, ceil?)
  end

  defp value_from(%ParsedFunds{} = parsed) do
    case Funds.from_parsed_funds(parsed, TokenDecimals.wart()) do
      {:ok, %Funds{amount: amount}} -> {:ok, amount}
      :error -> :error
    end
  end
end
