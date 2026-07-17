defmodule WarthogEx.NonceId do
  @moduledoc """
  Transaction nonce (32-bit unsigned integer).

  Every transaction requires a unique nonce to prevent replay attacks.
  Valid range: `[0, 0xFFFFFFFF]` (`0` to `4_294_967_295`).

  ## Example

      iex> {:ok, nonce} = WarthogEx.NonceId.from_number(12345)
      iex> nonce.value
      12345

      iex> WarthogEx.NonceId.random()
      %WarthogEx.NonceId{value: _}
  """

  alias WarthogEx.NonceId

  @type t :: %__MODULE__{value: non_neg_integer()}
  defstruct value: 0

  @max_u32 0xFFFFFFFF

  @doc """
  Validate that a number is a valid 32-bit unsigned integer.

  Returns `true` if `value` is in the range `[0, 0xFFFFFFFF]`, otherwise `false`.
  """
  @spec validate(integer()) :: boolean()
  def validate(value) when is_integer(value) do
    value >= 0 and value <= @max_u32
  end

  def validate(_), do: false

  @doc """
  Create a `NonceId` from a number.

  Returns `{:ok, %NonceId{}}` if the value is valid, otherwise `:error`.
  """
  @spec from_number(integer()) :: {:ok, t()} | :error
  def from_number(value) when is_integer(value) do
    if validate(value) do
      {:ok, %NonceId{value: value}}
    else
      :error
    end
  end

  def from_number(_), do: :error

  @doc """
  Like `from_number/1` but raises on invalid input.
  """
  @spec from_number!(integer()) :: t()
  def from_number!(value) do
    case from_number(value) do
      {:ok, nonce} -> nonce
      :error -> raise ArgumentError, "invalid nonce: #{inspect(value)} (must be 0..0xFFFFFFFF)"
    end
  end

  @doc """
  Generate a random `NonceId` in the valid 32-bit range.
  """
  @spec random() :: t()
  def random do
    %NonceId{value: :rand.uniform(@max_u32 + 1) - 1}
  end
end
