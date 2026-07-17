defmodule WarthogEx.Address do
  @moduledoc """
  Warthog address with SHA-256 checksum validation.

  Addresses are 20 bytes (40 hex chars) of payload with a 4-byte
  (8 hex chars) SHA-256 checksum appended, totalling 48 hex
  characters.

  ## Example

      iex> {:ok, addr} = WarthogEx.Address.from_hex(\"0000000000000000000000000000000000000000de47c9b2\")
      iex> WarthogEx.Address.validate(addr.hex)
      true

      iex> WarthogEx.Address.from_hex(\"abc\")
      :error
  """

  alias WarthogEx.Address

  @type t :: %__MODULE__{hex: String.t()}
  defstruct [:hex]

  @payload_size 20
  @checksum_size 4
  @hex_size (@payload_size + @checksum_size) * 2

  @doc """
  Parse and validate a 48-character hex address with checksum.

  Returns `{:ok, %Address{}}` if valid, otherwise `:error`.
  """
  @spec from_hex(String.t()) :: {:ok, t()} | :error
  def from_hex(hex) when is_binary(hex) and byte_size(hex) == @hex_size do
    with {:ok, payload} <- decode_hex_prefix(hex, 0, @payload_size * 2),
         {:ok, checksum} <- decode_hex_prefix(hex, @payload_size * 2, @checksum_size * 2),
         :ok <- verify_checksum(payload, checksum) do
      {:ok, %Address{hex: String.downcase(hex)}}
    else
      _ -> :error
    end
  end

  def from_hex(_), do: :error

  @doc """
  Create an address from a raw 40-character hex string (20 bytes, no checksum).

  Computes and appends the SHA-256 checksum. Returns `{:ok, %Address{}}` if
  the input is valid, otherwise `:error`.
  """
  @spec from_raw(String.t()) :: {:ok, t()} | :error
  def from_raw(raw) when is_binary(raw) and byte_size(raw) == @payload_size * 2 do
    with {:ok, payload} <- Base.decode16(raw, case: :mixed) do
      checksum = checksum(payload)
      {:ok, %Address{hex: Base.encode16(payload <> checksum, case: :lower)}}
    end
  end

  def from_raw(_), do: :error

  @doc """
  Like `from_hex/1` but raises on invalid input.
  """
  @spec from_hex!(String.t()) :: t()
  def from_hex!(hex) do
    case from_hex(hex) do
      {:ok, address} ->
        address

      :error ->
        raise ArgumentError,
              "invalid address hex: expected a 48-character hex string with valid checksum"
    end
  end

  @doc """
  Like `from_raw/1` but raises on invalid input.
  """
  @spec from_raw!(String.t()) :: t()
  def from_raw!(raw) do
    case from_raw(raw) do
      {:ok, address} ->
        address

      :error ->
        raise ArgumentError,
              "invalid raw address hex: expected a 40-character hex string"
    end
  end

  @doc """
  Validate any 48-character hex address string.
  """
  @spec validate(String.t()) :: boolean()
  def validate(address) when is_binary(address) do
    case from_hex(address) do
      {:ok, _} -> true
      :error -> false
    end
  end

  def validate(_), do: false

  @doc """
  Compute the SHA-256 checksum of a 20-byte address payload.

  Returns the first 4 bytes of `SHA-256(payload)`.
  """
  @spec checksum(binary()) :: binary()
  def checksum(payload) when byte_size(payload) == @payload_size do
    payload
    |> compute_sha256()
    |> binary_part(0, @checksum_size)
  end

  defp verify_checksum(payload, checksum) do
    if checksum(payload) == checksum, do: :ok, else: :error
  end

  defp compute_sha256(data), do: :crypto.hash(:sha256, data)

  defp decode_hex_prefix(hex, start, length) do
    slice = binary_part(hex, start, length)

    case Base.decode16(slice, case: :mixed) do
      {:ok, _} = ok -> ok
      :error -> :error
    end
  end
end
