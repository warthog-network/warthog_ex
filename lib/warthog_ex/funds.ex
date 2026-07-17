defmodule WarthogEx.Funds do
  @moduledoc """
  Represents a token amount with a specific number of decimals.

  The `amount` is the integer representation of the token's smallest unit.
  For example, with 4 decimals, the value `123.45` is stored as `1_234_500`.

  ## Example

      iex> {:ok, f} = WarthogEx.Funds.parse(\"1.123\", %WarthogEx.TokenDecimals{decimals: 4})
      iex> f.amount
      11230
  """

  alias WarthogEx.Funds
  alias WarthogEx.ParsedFunds
  alias WarthogEx.TokenDecimals

  defstruct [:amount]

  @type t :: %__MODULE__{amount: non_neg_integer()}

  @doc """
  Parse a decimal string to `Funds`.

  Returns `{:ok, %Funds{}}` if valid, otherwise `:error`.
  """
  @spec parse(String.t(), TokenDecimals.t()) :: {:ok, t()} | :error
  def parse(string, %TokenDecimals{} = decimals) do
    with {:ok, parsed} <- ParsedFunds.parse(string),
         {:ok, value} <- value_from(parsed, decimals.decimals) do
      {:ok, %Funds{amount: value}}
    end
  end

  @doc """
  Like `parse/2` but raises on invalid input.
  """
  @spec parse!(String.t(), TokenDecimals.t()) :: t()
  def parse!(string, decimals) do
    case parse(string, decimals) do
      {:ok, funds} -> funds
      :error -> raise ArgumentError, "invalid funds string: #{inspect(string)}"
    end
  end

  @doc """
  Convert a `ParsedFunds` into `Funds` at the given decimal precision.

  Returns `{:ok, %Funds{}}` if valid, otherwise `:error`.
  """
  @spec from_parsed_funds(ParsedFunds.t(), TokenDecimals.t()) :: {:ok, t()} | :error
  def from_parsed_funds(%ParsedFunds{} = parsed, %TokenDecimals{} = decimals) do
    case value_from(parsed, decimals.decimals) do
      {:ok, value} -> {:ok, %Funds{amount: value}}
      :error -> :error
    end
  end

  @doc """
  Like `from_parsed_funds/2` but raises on invalid input.
  """
  @spec from_parsed_funds!(ParsedFunds.t(), TokenDecimals.t()) :: t()
  def from_parsed_funds!(parsed, decimals) do
    case from_parsed_funds(parsed, decimals) do
      {:ok, funds} -> funds
      :error -> raise ArgumentError, "invalid parsed funds for given decimals"
    end
  end

  defp value_from(%ParsedFunds{} = parsed, decimals) do
    if parsed.decimal_places > decimals do
      :error
    else
      zeros = decimals - parsed.decimal_places

      try do
        {:ok, multiply_by_ten(parsed.val, zeros)}
      catch
        :overflow -> :error
      end
    end
  end

  defp multiply_by_ten(value, 0), do: value

  defp multiply_by_ten(value, n) do
    if div(WarthogEx.max_u64(), 10) < value do
      throw(:overflow)
    else
      multiply_by_ten(value * 10, n - 1)
    end
  end
end
