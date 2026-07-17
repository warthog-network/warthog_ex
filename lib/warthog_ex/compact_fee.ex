defmodule WarthogEx.CompactFee do
  @moduledoc """
  Warthog's internal 16-bit compact fee representation.

  Used for compact storage and transmission of transaction fees within the
  protocol. **This is NOT used in transaction submission API — use `RoundedFee`
  instead.**
  """

  import Bitwise

  alias WarthogEx.CompactFee
  alias WarthogEx.Wart

  defstruct [:exponent, :mantissa]

  @type t :: %__MODULE__{exponent: non_neg_integer(), mantissa: non_neg_integer()}

  @threshold 0x07FF
  @min_11_bit 0x0400
  @max_exponent 15
  @max_mantissa 1023

  @doc """
  Create a `CompactFee` from a `Wart` amount. Pass `ceil: true` to round up,
  `ceil: false` to round down.
  """
  @spec from_wart(Wart.t(), boolean()) :: t()
  def from_wart(%Wart{e8: 0}, _ceil?), do: %CompactFee{exponent: 0, mantissa: 0}

  def from_wart(%Wart{e8: e8}, ceil?) when is_boolean(ceil?) do
    {e, normalized, inexact?} = shift_until_under(e8, 10, ceil?)

    cond do
      ceil? and inexact? ->
        apply_ceiling(e, normalized)

      true ->
        finalize(e, normalized)
    end
  end

  @doc """
  Convert a `CompactFee` to a `Wart`.
  """
  @spec to_wart(t()) :: Wart.t()
  def to_wart(%CompactFee{exponent: e, mantissa: m}) when e < 10 do
    shift = 10 - e
    value = (1024 + m) >>> shift
    {:ok, w} = Wart.from_e8(value)
    w
  end

  def to_wart(%CompactFee{exponent: e, mantissa: m}) when e >= 10 do
    shift = e - 10
    value = (1024 + m) <<< shift
    {:ok, w} = Wart.from_e8(value)
    w
  end

  defp shift_until_under(e8, e, ceil?) do
    if e8 > @threshold do
      inexact? = ceil? and (e8 &&& 1) == 1
      {final_e, normalized, prev_inexact?} = shift_until_under(e8 >>> 1, e + 1, ceil?)
      {final_e, normalized, inexact? or prev_inexact?}
    else
      {e, e8, false}
    end
  end

  defp apply_ceiling(e, e8) do
    rounded = e8 + 1

    cond do
      rounded > @threshold ->
        new_e = e + 1

        if new_e > @max_exponent do
          %CompactFee{exponent: @max_exponent, mantissa: @max_mantissa}
        else
          finalize(new_e, rounded >>> 1)
        end

      true ->
        finalize(e, rounded)
    end
  end

  defp finalize(e, e8) do
    {final_e, normalized} = normalize(e, e8)
    %CompactFee{exponent: final_e, mantissa: normalized - @min_11_bit}
  end

  defp normalize(e, e8) do
    if e8 < @min_11_bit do
      normalize(e - 1, e8 <<< 1)
    else
      {e, e8}
    end
  end
end
