defmodule WarthogEx.Price do
  @moduledoc """
  Represents a swap price in normalized mantissa/exponent format.

  - **Mantissa**: 16 bits, must be in `[0x8000, 0xFFFF]` (high bit set).
  - **Exponent**: 8 bits, stored with offset `+63` internally to map to
    `[0, 127]`.

  The price is interpreted as a quotient of base and quote amount *integers*,
  i.e. when creating or printing this representation you must account for
  the number of decimals of the involved base asset.

  Used in limit swap transactions.

  ## Example

      iex> {:ok, p} = WarthogEx.Price.from_hex(\"c0e74d\")
      iex> WarthogEx.Price.to_hex(p)
      \"c0e74d\"
  """

  alias WarthogEx.Frexp
  alias WarthogEx.Price
  alias WarthogEx.TokenDecimals

  @min_mantissa 0x8000
  @max_mantissa 0xFFFF
  @max_exponent_internal 127
  @mantissa_offset 63
  @hex_size 6

  defstruct [:mantissa, :exponent]

  @type t :: %__MODULE__{
          mantissa: non_neg_integer(),
          exponent: non_neg_integer()
        }

  @doc """
  Get the maximum possible price.
  """
  @spec max() :: t()
  def max, do: %Price{mantissa: @max_mantissa, exponent: @max_exponent_internal}

  @doc """
  Create a `Price` from raw mantissa and exponent values.

  `mantissa` is the 16-bit normalized value. `exponent` is the raw
  representation **before** the `+63` adjustment (must be in `[0, 127]`).

  Returns `{:ok, %Price{}}` if valid, otherwise `:error`.
  """
  @spec from_mantissa_exponent(non_neg_integer(), integer()) :: {:ok, t()} | :error
  def from_mantissa_exponent(mantissa, exponent)
      when is_integer(mantissa) and is_integer(exponent) do
    adjusted = exponent + @mantissa_offset

    if mantissa >= @min_mantissa and mantissa <= @max_mantissa and adjusted >= 0 and
         adjusted <= @max_exponent_internal do
      {:ok, %Price{mantissa: mantissa, exponent: adjusted}}
    else
      :error
    end
  end

  def from_mantissa_exponent(_, _), do: :error

  @doc """
  Like `from_mantissa_exponent/2` but raises on invalid input.
  """
  @spec from_mantissa_exponent!(non_neg_integer(), integer()) :: t()
  def from_mantissa_exponent!(mantissa, exponent) do
    case from_mantissa_exponent(mantissa, exponent) do
      {:ok, price} ->
        price

      :error ->
        raise ArgumentError, "invalid Price mantissa/exponent: #{inspect({mantissa, exponent})}"
    end
  end

  @doc """
  Create a `Price` from a decimal number, given the base asset decimals.

  Pass `ceil: true` to round up, `ceil: false` (default) to round down.

  Returns `{:ok, %Price{}}` if valid, otherwise `:error`.
  """
  @spec from_number_decimals(number(), TokenDecimals.t(), boolean()) :: {:ok, t()} | :error
  def from_number_decimals(d, %TokenDecimals{} = base_decimals, ceil? \\ false)
      when is_number(d) and is_boolean(ceil?) do
    adjusted = d * :math.pow(10, 8 - base_decimals.decimals)
    from_double_internal(adjusted, ceil?)
  end

  @doc """
  Low-level factory. **Library users should prefer
  `from_number_decimals/3`**.

  Returns `{:ok, %Price{}}` if valid, otherwise `:error`.
  """
  @spec from_double_internal(number() | atom(), boolean()) :: {:ok, t()} | :error
  def from_double_internal(d, ceil? \\ false) when is_boolean(ceil?) do
    cond do
      not is_number(d) ->
        :error

      d <= 0 ->
        :error

      not finite?(d) ->
        :error

      true ->
        {mantissa, exponent} = Frexp.frexp(d)
        mantissa_scaled = floor(mantissa * 65_536)
        exact? = mantissa * 65_536 == mantissa_scaled

        if ceil? and not exact? do
          new_mantissa = mantissa_scaled + 1

          if new_mantissa >= 65_536 do
            from_mantissa_exponent(div(new_mantissa, 2), exponent + 1)
          else
            from_mantissa_exponent(new_mantissa, exponent)
          end
        else
          from_mantissa_exponent(mantissa_scaled, exponent)
        end
    end
  end

  defp finite?(d) when is_integer(d), do: true

  defp finite?(d) when is_float(d) do
    not (:erlang.==(d, :infinity) or :erlang.==(d, :"-infinity") or :erlang.==(d, :nan))
  end

  @doc """
  Like `from_number_decimals/3` but raises on invalid input.
  """
  @spec from_number_decimals!(number(), TokenDecimals.t(), boolean()) :: t()
  def from_number_decimals!(d, base_decimals, ceil? \\ false) do
    case from_number_decimals(d, base_decimals, ceil?) do
      {:ok, price} -> price
      :error -> raise ArgumentError, "invalid Price from number #{inspect(d)}"
    end
  end

  @doc """
  Like `from_double_internal/2` but raises on invalid input.
  """
  @spec from_double_internal!(number(), boolean()) :: t()
  def from_double_internal!(d, ceil? \\ false) do
    case from_double_internal(d, ceil?) do
      {:ok, price} -> price
      :error -> raise ArgumentError, "invalid Price from double #{inspect(d)}"
    end
  end

  @doc """
  Like `from_hex/1` but raises on invalid input.
  """
  @spec from_hex!(String.t()) :: t()
  def from_hex!(hex) do
    case from_hex(hex) do
      {:ok, price} -> price
      :error -> raise ArgumentError, "invalid Price hex: #{inspect(hex)}"
    end
  end

  @doc """
  Convert a `Price` to a 6-character hex string for transaction generation.
  """
  @spec to_hex(t()) :: String.t()
  def to_hex(%Price{mantissa: mantissa, exponent: exponent}) do
    mantissa_hex =
      mantissa
      |> Integer.to_string(16)
      |> String.downcase()
      |> String.pad_leading(4, "0")

    exponent_hex =
      exponent
      |> Integer.to_string(16)
      |> String.downcase()
      |> String.pad_leading(2, "0")

    mantissa_hex <> exponent_hex
  end

  @doc """
  Parse a `Price` from a 6-character hex string.

  Returns `{:ok, %Price{}}` if valid, otherwise `:error`.

  Both the mantissa and exponent must satisfy the class invariants
  (`mantissa ∈ [0x8000, 0xFFFF]`, internal `exponent ∈ [0, 127]`).
  This matches the constraint enforced by `from_mantissa_exponent/2`.
  """
  @spec from_hex(String.t()) :: {:ok, t()} | :error
  def from_hex(hex) when is_binary(hex) and byte_size(hex) == @hex_size do
    case Integer.parse(hex, 16) do
      {parsed, ""} ->
        mantissa = Bitwise.bsr(parsed, 8)
        exponent = Bitwise.band(parsed, 0xFF)

        if mantissa >= @min_mantissa and mantissa <= @max_mantissa and
             exponent >= 0 and exponent <= @max_exponent_internal do
          {:ok, %Price{mantissa: mantissa, exponent: exponent}}
        else
          :error
        end

      _ ->
        :error
    end
  end

  def from_hex(_), do: :error

  @doc """
  Get the base-2 exponent (the exponent after the `+63` adjustment has been
  removed, and reduced by 16 for the implicit mantissa scaling).
  """
  @spec mantissa_exponent2(t()) :: integer()
  def mantissa_exponent2(%Price{exponent: e}), do: e - @mantissa_offset - 16

  @doc """
  Convert price to a raw double (without decimal adjustment).

  Equivalent to `mantissa * 2 ** mantissa_exponent2/1`.
  """
  @spec to_double_raw(t()) :: float()
  def to_double_raw(%Price{} = price) do
    price.mantissa * :math.pow(2, mantissa_exponent2(price))
  end

  @doc """
  Convert price to a double with asset-decimals adjustment.
  """
  @spec to_double_adjusted(t(), TokenDecimals.t()) :: float()
  def to_double_adjusted(%Price{} = price, %TokenDecimals{} = dec) do
    b10e = TokenDecimals.wart().decimals - dec.decimals
    to_double_raw(price) * :math.pow(10, -b10e)
  end
end
