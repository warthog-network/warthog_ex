defmodule WarthogEx.TokenDecimals do
  @moduledoc """
  Represents the number of decimal places for a token.

  Valid range: `0` to `18`. WART uses 8 decimal places.

  Per Elixir convention, `new/1` returns `{:ok, t()} | :error` for safe
  use, and `new!/1` raises on invalid input.

  ## Example

      iex> WarthogEx.TokenDecimals.wart().decimals
      8

      iex> {:ok, td} = WarthogEx.TokenDecimals.new(4)
      iex> td.decimals
      4
  """

  defstruct decimals: 0

  @type t :: %__MODULE__{decimals: non_neg_integer()}

  @doc """
  Pre-configured WART decimals (8).
  """
  @spec wart() :: t()
  def wart, do: %__MODULE__{decimals: 8}

  @doc """
  Pre-configured Liquidity decimals (8).
  """
  @spec liquidity() :: t()
  def liquidity, do: %__MODULE__{decimals: 8}

  @doc """
  Build a new `TokenDecimals`.

  Returns `{:ok, t()}` if `decimals` is in `[0, 18]`, otherwise `:error`.
  """
  @spec new(integer()) :: {:ok, t()} | :error
  def new(decimals) when is_integer(decimals) and decimals >= 0 and decimals <= 18 do
    {:ok, %__MODULE__{decimals: decimals}}
  end

  def new(_), do: :error

  @doc """
  Build a new `TokenDecimals`, raising on invalid input.
  """
  @spec new!(integer()) :: t()
  def new!(decimals) do
    case new(decimals) do
      {:ok, td} -> td
      :error -> raise ArgumentError, "invalid decimals: #{inspect(decimals)} (must be 0..18)"
    end
  end
end
