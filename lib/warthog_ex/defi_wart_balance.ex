defmodule WarthogEx.DeFiWartBalance do
  @moduledoc """
  WART balance of an account on the DeFi node.

  The DeFi node reports the balance three ways: what the account owns in
  total, what is locked in open limit orders, and what is locked by
  transactions still sitting in the mempool. The spendable amount is what is
  left of the total after those two.
  """

  alias WarthogEx.DeFiWartBalance
  alias WarthogEx.Wart

  defstruct [:total, :locked, :mempool]

  @type t :: %__MODULE__{
          total: Wart.t(),
          locked: Wart.t(),
          mempool: Wart.t()
        }

  @doc """
  Read a balance out of a `/account/{address}/wart_balance` response.

  The decimal string is used, not the integer: the integer is a JSON number,
  and a balance above 2^53 does not survive that.

  Returns `{:ok, %DeFiWartBalance{}}` if the payload is well formed and the
  three amounts add up, otherwise `:error`.
  """
  @spec parse(term()) :: {:ok, t()} | :error
  def parse(data) when is_map(data) do
    with %{"wart" => %{} = wart} <- data,
         {:ok, total} <- parse_wart(wart["total"]),
         {:ok, locked} <- parse_wart(wart["locked"]),
         {:ok, mempool} <- parse_wart(wart["mempool"]),
         true <- total.e8 >= locked.e8 + mempool.e8 do
      {:ok, %DeFiWartBalance{total: total, locked: locked, mempool: mempool}}
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
  @spec free(t()) :: {:ok, Wart.t()} | :error
  def free(%DeFiWartBalance{total: total, locked: locked, mempool: mempool}) do
    free = total.e8 - locked.e8 - mempool.e8

    if free < 0 do
      :error
    else
      {:ok, Wart.from_e8!(free)}
    end
  end

  defp parse_wart(%{"str" => str}) when is_binary(str), do: Wart.parse(str)
  defp parse_wart(_), do: :error
end
