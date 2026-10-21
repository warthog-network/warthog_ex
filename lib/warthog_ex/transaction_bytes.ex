defmodule WarthogEx.TransactionBytes do
  @moduledoc """
  The binary encodings the transaction builders sign.

  Both node families sign the same bytes for a WART transfer, so a signature
  produced for one is valid for the other. Only the JSON around them differs.
  """

  alias WarthogEx.Address
  alias WarthogEx.ChainPin
  alias WarthogEx.NonceId
  alias WarthogEx.RoundedFee
  alias WarthogEx.Wart

  @doc """
  The bytes signed for a WART transfer.
  """
  @spec wart_transfer_bytes(
          ChainPin.t(),
          RoundedFee.t(),
          NonceId.t(),
          Address.t(),
          Wart.t()
        ) :: binary()
  def wart_transfer_bytes(chain_pin, fee, nonce_id, to_addr, wart) do
    bin(chain_pin.pin_hash) <>
      u32be(chain_pin.pin_height) <>
      u32be(nonce_id.value) <>
      <<0, 0, 0>> <>
      u64be(fee.e8) <>
      address_bytes(to_addr.hex) <>
      u64be(wart.e8)
  end

  @doc """
  Decode a hex string into bytes.
  """
  @spec bin(String.t()) :: binary()
  def bin(hex) when is_binary(hex), do: Base.decode16!(hex, case: :mixed)

  @doc """
  Encode an unsigned 32-bit integer, big endian.
  """
  @spec u32be(non_neg_integer()) :: binary()
  def u32be(value) when is_integer(value) and value >= 0 and value <= 0xFFFFFFFF do
    <<value::big-32>>
  end

  @doc """
  Encode an unsigned 64-bit integer, big endian.
  """
  @spec u64be(non_neg_integer()) :: binary()
  def u64be(value) when is_integer(value) and value >= 0 do
    <<value::big-64>>
  end

  @doc """
  The 20 raw bytes of an address, without its checksum.
  """
  @spec address_bytes(String.t()) :: binary()
  def address_bytes(address) when is_binary(address) do
    <<raw::binary-size(40), _checksum::binary-size(8)>> = address
    Base.decode16!(raw, case: :mixed)
  end
end
