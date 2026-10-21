defmodule WarthogEx.TokenBalance do
  @moduledoc """
  Token balance of an account on the DeFi node.

  Like the WART balance, the DeFi node reports it three ways: what the
  account owns, what is locked in open limit orders, and what is locked by
  transactions in the mempool.
  """

  alias WarthogEx.Funds
  alias WarthogEx.TokenBalance
  alias WarthogEx.TokenDecimals

  defstruct [:name, :decimals, :total, :locked, :mempool]

  @type t :: %__MODULE__{
          name: String.t(),
          decimals: TokenDecimals.t(),
          total: Funds.t(),
          locked: Funds.t(),
          mempool: Funds.t()
        }

  @doc """
  Read a balance out of a `/account/{address}/balance/asset:{hash}` response.

  The decimal string is used, not the integer, for the same reason as in
  `WarthogEx.DeFiWartBalance`.

  Returns `{:ok, %TokenBalance{}}` if the payload is well formed and the
  three amounts add up, otherwise `:error`.
  """
  @spec parse(term()) :: {:ok, t()} | :error
  def parse(data) when is_map(data) do
    with %{"token" => %{} = token} <- data,
         %{"balance" => %{} = balance} <- data,
         {:ok, name, decimals} <- parse_token(token),
         {:ok, total} <- parse_funds(balance["total"]),
         {:ok, locked} <- parse_funds(balance["locked"]),
         {:ok, mempool} <- parse_funds(balance["mempool"]),
         true <- total.amount >= locked.amount + mempool.amount do
      {:ok,
       %TokenBalance{
         name: name,
         decimals: decimals,
         total: total,
         locked: locked,
         mempool: mempool
       }}
    else
      _ -> :error
    end
  end

  def parse(_data), do: :error

  @doc """
  The amount that can be spent now: total - locked - mempool.

  Returns `:error` if the balance does not add up, which the node also
  treats as an error rather than a balance.
  """
  @spec free(t()) :: {:ok, Funds.t()} | :error
  def free(%TokenBalance{total: total, locked: locked, mempool: mempool}) do
    free = total.amount - locked.amount - mempool.amount

    if free < 0 do
      :error
    else
      {:ok, Funds.from_amount!(free)}
    end
  end

  defp parse_token(%{"name" => name, "decimals" => decimals}) do
    if is_binary(name) and is_integer(decimals) and decimals >= 0 do
      {:ok, name, %TokenDecimals{decimals: decimals}}
    else
      :error
    end
  end

  defp parse_token(_), do: :error

  defp parse_funds(%{"str" => str, "decimals" => decimals})
       when is_binary(str) and is_integer(decimals) and decimals >= 0 do
    Funds.parse(str, %TokenDecimals{decimals: decimals})
  end

  defp parse_funds(_), do: :error
end
