defmodule WarthogEx.Frexp do
  @moduledoc false
  # Port of the locutus.js implementation of `frexp` for the C standard
  # library function. Returns `{mantissa, exponent}` such that
  # `n == mantissa * :math.pow(2, exponent)`, with `0.5 <= abs(mantissa) < 1.0`
  # for non-zero finite numbers.

  @doc """
  Decompose a float into a normalized fraction and a power-of-two exponent.

  Returns `{mantissa, exponent}` where `mantissa * 2 ** exponent == n`
  for non-zero finite numbers. For `0.0`, `-0.0`, `:nan`, `:infinity`, and
  `:-infinity` the second element is `0` and the first mirrors the input.
  """
  @spec frexp(number()) :: {number(), integer()}
  def frexp(+0.0), do: {+0.0, 0}
  def frexp(:nan), do: {:nan, 0}
  def frexp(:infinity), do: {:infinity, 0}
  def frexp(:"-infinity"), do: {:"-infinity", 0}

  def frexp(arg) when is_number(arg) do
    if arg == 0 do
      {if(arg < 0, do: -0.0, else: +0.0), 0}
    else
      abs_arg = abs(arg)
      exp = max(-1023, floor(log2(abs_arg)) + 1)
      x = abs_arg * :math.pow(2, -exp)
      {mantissa, exp} = adjust(x, exp)
      if arg < 0, do: {-mantissa, exp}, else: {mantissa, exp}
    end
  end

  defp log2(n), do: :math.log2(n)

  defp adjust(x, exp) do
    cond do
      x < 0.5 -> adjust(x * 2, exp - 1)
      x >= 1 -> adjust(x * 0.5, exp + 1)
      true -> {x, exp}
    end
  end
end
