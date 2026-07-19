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

  @type signature ::
          {binary(), binary(), non_neg_integer(), String.t()}

  @type signature_input ::
          signature() | String.t()

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
  Hash arbitrary bytes with SHA-256 and sign with the account's private key.

  Produces a 65-byte signature (`r || s || recid`) using the same
  secp256k1 configuration as transaction signing (low-s / canonical).

  Returns `{:ok, {r, s, recid, signature_hex}} | :error`.
  """
  @spec sign_bytes(t(), binary()) :: {:ok, signature()} | :error
  def sign_bytes(%Account{private_key_hex: hex}, message)
      when is_binary(hex) and byte_size(hex) == 64 and is_binary(message) do
    with {:ok, private_key} <- Base.decode16(hex, case: :lower) do
      sign_bytes_raw(private_key, message)
    end
  end

  def sign_bytes(_, _), do: :error

  @doc """
  Like `sign_bytes/2` but raises on failure.
  """
  @spec sign_bytes!(t(), binary()) :: signature()
  def sign_bytes!(account, message) do
    case sign_bytes(account, message) do
      {:ok, sig} -> sig
      :error -> raise ArgumentError, "failed to sign message with account"
    end
  end

  @doc """
  Recover the compressed public key (hex, 66 chars) that produced the
  given signature for the given message.

  `signature` accepts either:
  - a `{r, s, recid}` tuple (raw bytes for r, s; integer recid)
  - a 130-char hex string (`r || s || recid`)
  """
  @spec recover_public_key(binary(), signature_input()) :: {:ok, String.t()} | :error
  def recover_public_key(message, signature) when is_binary(message) do
    with {:ok, {r, s, recid}} <- normalize_signature(signature) do
      digest = :crypto.hash(:sha256, message)

      with {:ok, uncompressed} <- ExSecp256k1.recover_compact(digest, r <> s, recid),
           {:ok, compressed} <- ExSecp256k1.public_key_compress(uncompressed) do
        {:ok, Base.encode16(compressed, case: :lower)}
      end
    end
  end

  def recover_public_key(_, _), do: :error

  @doc """
  Like `recover_public_key/2` but raises on failure.
  """
  @spec recover_public_key!(binary(), signature_input()) :: String.t()
  def recover_public_key!(message, signature) do
    case recover_public_key(message, signature) do
      {:ok, pubkey_hex} -> pubkey_hex
      :error -> raise ArgumentError, "failed to recover public key"
    end
  end

  @doc """
  Recover the Warthog address that produced the given signature for the
  given message. Derived from the recovered public key via the same
  `RIPEMD-160(SHA-256(pubkey)) + 4-byte checksum` pipeline the protocol
  uses for addresses.
  """
  @spec recover_address(binary(), signature_input()) :: {:ok, Address.t()} | :error
  def recover_address(message, signature) do
    with {:ok, pubkey_hex} <- recover_public_key(message, signature),
         {:ok, pubkey_bytes} <- Base.decode16(pubkey_hex, case: :lower) do
      sha = :crypto.hash(:sha256, pubkey_bytes)
      ripe = :crypto.hash(:ripemd160, sha)
      Address.from_raw(Base.encode16(ripe, case: :lower))
    end
  end

  @doc """
  Like `recover_address/2` but raises on failure.
  """
  @spec recover_address!(binary(), signature_input()) :: Address.t()
  def recover_address!(message, signature) do
    case recover_address(message, signature) do
      {:ok, address} -> address
      :error -> raise ArgumentError, "failed to recover address"
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

  defp sign_bytes_raw(private_key, message) do
    digest = :crypto.hash(:sha256, message)
    sign_hash(private_key, digest)
  end

  defp sign_hash(private_key, digest) do
    case ExSecp256k1.sign_compact(digest, private_key) do
      {:ok, {compact, recid}} ->
        <<r::binary-size(32), s::binary-size(32)>> = compact
        signature_hex = Base.encode16(compact <> <<recid>>, case: :lower)
        {:ok, {r, s, recid, signature_hex}}

      error ->
        error
    end
  end

  defp normalize_signature({r, s, recid})
       when is_binary(r) and is_binary(s) and is_integer(recid) and recid in 0..3 do
    {:ok, {r, s, recid}}
  end

  defp normalize_signature(sig) when is_binary(sig) and byte_size(sig) == 130 do
    case Base.decode16(sig, case: :lower) do
      {:ok, <<r::binary-size(32), s::binary-size(32), recid_byte::binary-size(1)>>} ->
        recid = :binary.decode_unsigned(recid_byte)

        if recid in 0..3 do
          {:ok, {r, s, recid}}
        else
          :error
        end

      _ ->
        :error
    end
  end

  defp normalize_signature(_), do: :error
end
