defmodule WarthogEx.Liquidity do
  @moduledoc """
  Liquidity pool tokens with 8 decimal places.

  Used for liquidity deposit/withdrawal transactions.
  `1 unit = 100_000_000 E8`.

  ## Example

      iex> {:ok, l} = WarthogEx.Liquidity.parse(\"1.5\")
      iex> l.e8
      150000000
  """

  alias WarthogEx.Funds
  alias WarthogEx.Liquidity
  alias WarthogEx.ParsedFunds
  alias WarthogEx.TokenDecimals

  defstruct [:e8]

  @type t :: %__MODULE__{e8: non_neg_integer()}

  @doc """
  Parse a decimal string to `Liquidity`.

  Returns `{:ok, %Liquidity{}}` if valid, otherwise `:error`.
  """
  @spec parse(String.t()) :: {:ok, t()} | :error
  def parse(string) when is_binary(string) do
    with {:ok, parsed} <- ParsedFunds.parse(string),
         {:ok, value} <- value_from(parsed) do
      {:ok, %Liquidity{e8: value}}
    end
  end

  def parse(_), do: :error

  @doc """
  Like `parse/1` but raises on invalid input.
  """
  @spec parse!(String.t()) :: t()
  def parse!(string) do
    case parse(string) do
      {:ok, liq} -> liq
      :error -> raise ArgumentError, "invalid Liquidity string: #{inspect(string)}"
    end
  end

  @doc """
  Convert a `ParsedFunds` into `Liquidity`.

  Returns `{:ok, %Liquidity{}}` if valid, otherwise `:error`.
  """
  @spec from_parsed_funds(ParsedFunds.t()) :: {:ok, t()} | :error
  def from_parsed_funds(%ParsedFunds{} = parsed) do
    case value_from(parsed) do
      {:ok, value} -> {:ok, %Liquidity{e8: value}}
      :error -> :error
    end
  end

  @doc """
  Like `from_parsed_funds/1` but raises on invalid input.
  """
  @spec from_parsed_funds!(ParsedFunds.t()) :: t()
  def from_parsed_funds!(parsed) do
    case from_parsed_funds(parsed) do
      {:ok, liq} -> liq
      :error -> raise ArgumentError, "invalid parsed funds for Liquidity"
    end
  end

  @doc """
  Create `Liquidity` from a raw E8 value.

  Returns `{:ok, %Liquidity{}}` if the value is in `[0, MAX_U64]`, otherwise
  `:error`.
  """
  @spec from_e8(integer()) :: {:ok, t()} | :error
  def from_e8(e8) when is_integer(e8) and e8 >= 0 do
    if e8 > WarthogEx.max_u64() do
      :error
    else
      {:ok, %Liquidity{e8: e8}}
    end
  end

  def from_e8(_), do: :error

  @doc """
  Like `from_e8/1` but raises on invalid input.
  """
  @spec from_e8!(integer()) :: t()
  def from_e8!(e8) do
    case from_e8(e8) do
      {:ok, liq} -> liq
      :error -> raise ArgumentError, "invalid E8: #{inspect(e8)} (must be 0..0xFFFFFFFFFFFFFFFF)"
    end
  end

  defp value_from(%ParsedFunds{} = parsed) do
    case Funds.from_parsed_funds(parsed, TokenDecimals.liquidity()) do
      {:ok, %Funds{amount: amount}} -> {:ok, amount}
      :error -> :error
    end
  end
end
