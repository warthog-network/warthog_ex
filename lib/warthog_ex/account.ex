defmodule WarthogEx.Account do
  @moduledoc """
  Wallet account for signing transactions on the Warthog network.

  Uses secp256k1 elliptic curve for key management. The address is
  derived as `RIPEMD-160(SHA-256(compressed-public-key))` with a 4-byte
  SHA-256 checksum appended.

  Per Elixir convention, factory functions without a trailing `!` return
  `{:ok, t()} | :error`, while `!`-suffixed variants raise on invalid
  input.

  ## Example

      iex> account = WarthogEx.Account.from_random()
      iex> account.private_key_hex |> byte_size() |> Kernel.*(4)
      256

      iex> account = WarthogEx.Account.from_private_key_hex(\"966a71a98bb5d13e9116c0dffa3f1a7877e45c6f563897b96cfd5c59bf0803e0\")
      iex> account.address.hex
      \"3661579d61abde5837a8686dc4d65348a2fc61b1fe5f4093\"
  """

  alias ExSecp256k1
  alias WarthogEx.Account
  alias WarthogEx.Address

  @type t :: %__MODULE__{
          private_key_hex: String.t(),
          public_key_hex: String.t(),
          address: Address.t()
        }

  defstruct [:private_key_hex, :public_key_hex, :address]

  @doc """
  Generate a new random account with a fresh private key.
  """
  @spec from_random() :: t()
  def from_random do
    private_key = :crypto.strong_rand_bytes(32)
    from_private_key!(private_key)
  end

  @doc """
  Load an account from a 64-character hex private key.

  Returns `{:ok, t()}` if the hex is valid, otherwise `:error`.
  """
  @spec from_private_key_hex(String.t()) :: {:ok, t()} | :error
  def from_private_key_hex(hex) when is_binary(hex) and byte_size(hex) == 64 do
    with {:ok, private_key} <- Base.decode16(hex, case: :lower),
         {:ok, account} <- from_private_key(private_key) do
      {:ok, account}
    end
  end

  def from_private_key_hex(_), do: :error

  @doc """
  Load an account from a 64-character hex private key, raising on invalid input.
  """
  @spec from_private_key_hex!(String.t()) :: t()
  def from_private_key_hex!(hex) do
    case from_private_key_hex(hex) do
      {:ok, account} ->
        account

      :error ->
        raise ArgumentError,
              "invalid private key hex: expected a 64-character hex string, got: #{inspect(hex)}"
    end
  end

  @doc """
  Load an account from a raw 32-byte private key.

  Returns `{:ok, t()}` if the key is exactly 32 bytes, otherwise `:error`.
  """
  @spec from_private_key(binary()) :: {:ok, t()} | :error
  def from_private_key(private_key)
      when is_binary(private_key) and byte_size(private_key) == 32 do
    {:ok, do_from_private_key(private_key)}
  end

  def from_private_key(_), do: :error

  @doc """
  Load an account from a raw 32-byte private key, raising on invalid input.
  """
  @spec from_private_key!(binary()) :: t()
  def from_private_key!(private_key) do
    case from_private_key(private_key) do
      {:ok, account} ->
        account

      :error ->
        raise ArgumentError, "invalid private key: expected a 32-byte binary"
    end
  end

  @doc """
  Get the address for the account.
  """
  @spec get_address(t()) :: Address.t()
  def get_address(%Account{address: address}), do: address

  @doc """
  Get the private key as a 64-character hex string (no `0x` prefix).
  """
  @spec get_private_key_hex(t()) :: String.t()
  def get_private_key_hex(%Account{private_key_hex: hex}), do: hex

  @doc """
  Sign a 32-byte hash with the account's private key, producing a 65-byte
  signature (`r || s || recid`).

  Returns `{:ok, {r, s, recid, signature_hex}}`.
  """
  @spec sign(t(), binary()) ::
          {:ok, {binary(), binary(), non_neg_integer(), String.t()}} | :error
  def sign(%Account{private_key_hex: hex}, hash)
      when is_binary(hash) and byte_size(hash) == 32 do
    with {:ok, private_key} <- Base.decode16(hex, case: :lower),
         {:ok, {compact, recid}} <- ExSecp256k1.sign_compact(hash, private_key) do
      <<r::binary-size(32), s::binary-size(32)>> = compact
      signature_hex = Base.encode16(compact <> <<recid>>, case: :lower)
      {:ok, {r, s, recid, signature_hex}}
    end
  end

  def sign(_, _), do: :error

  @doc """
  Like `sign/2` but raises on failure.
  """
  @spec sign!(t(), binary()) :: {binary(), binary(), non_neg_integer(), String.t()}
  def sign!(account, hash) do
    case sign(account, hash) do
      {:ok, sig} -> sig
      :error -> raise ArgumentError, "failed to sign hash with account"
    end
  end

  defp do_from_private_key(private_key) do
    {:ok, public_key} = ExSecp256k1.create_public_key(private_key)
    {:ok, compressed} = ExSecp256k1.public_key_compress(public_key)
    private_key_hex = Base.encode16(private_key, case: :lower)
    public_key_hex = Base.encode16(compressed, case: :lower)
    address = derive_address(compressed)

    %Account{
      private_key_hex: private_key_hex,
      public_key_hex: public_key_hex,
      address: address
    }
  end

  defp derive_address(compressed_pubkey) do
    sha256_hash = :crypto.hash(:sha256, compressed_pubkey)
    ripemd160_hash = :crypto.hash(:ripemd160, sha256_hash)
    {:ok, address} = Address.from_raw(Base.encode16(ripemd160_hash, case: :lower))
    address
  end
end
