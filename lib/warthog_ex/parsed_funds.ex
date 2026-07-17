defmodule WarthogEx.ParsedFunds do
  @moduledoc """
  Represents a parsed decimal string as an integer plus a decimal-place count.

  Used internally for parsing currency strings.

  ## Example

      iex> {:ok, parsed} = WarthogEx.ParsedFunds.parse(\"123.45\")
      iex> {parsed.val, parsed.decimal_places}
      {12345, 2}
  """

  alias WarthogEx.ParsedFunds

  @max_digits 20

  defstruct [:val, :decimal_places]

  @type t :: %__MODULE__{
          val: non_neg_integer(),
          decimal_places: non_neg_integer()
        }

  @doc """
  Parse a decimal string into a `ParsedFunds`.

  Returns `{:ok, %ParsedFunds{}}` if valid, otherwise `:error`.
  """
  @spec parse(String.t()) :: {:ok, t()} | :error
  def parse(string) when is_binary(string), do: do_parse(string, "", 0, false)

  def parse(_), do: :error

  @doc """
  Parse a decimal string, raising if invalid.
  """
  @spec parse!(String.t()) :: t()
  def parse!(string) when is_binary(string) do
    case parse(string) do
      {:ok, parsed} -> parsed
      :error -> raise ArgumentError, "invalid decimal string: #{inspect(string)}"
    end
  end

  defp do_parse(<<>>, "", _digits, _dot_found), do: :error

  defp do_parse(<<>>, str, digits, _dot_found) do
    val = String.to_integer(str)

    if val > WarthogEx.max_u64() do
      :error
    else
      {:ok, %ParsedFunds{val: val, decimal_places: digits}}
    end
  end

  defp do_parse(<<?., rest::binary>>, str, digits, false) do
    do_parse(rest, str, digits, true)
  end

  defp do_parse(<<c, rest::binary>>, str, digits, dot_found)
       when c >= ?0 and c <= ?9 do
    if String.length(str) >= @max_digits do
      :error
    else
      do_parse(rest, str <> <<c>>, digits + if(dot_found, do: 1, else: 0), dot_found)
    end
  end

  defp do_parse(_, _, _, _), do: :error
end
