defmodule WarthogEx.HDWallet do
  @moduledoc """
  BIP-44 hierarchical deterministic wallet for Warthog.

  Uses the derivation path `m/44'/2070'/0'` for Warthog accounts
  (coin type `2070` is registered to Warthog).

  ## Example

      iex> mnemonic = \"abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about\"
      iex> wallet = WarthogEx.HDWallet.from_mnemonic(mnemonic)
      iex> account = WarthogEx.HDWallet.derive_account_at_index(wallet, 0)
      iex> byte_size(account.address.hex)
      48
  """

  alias Cryptopunk
  alias Cryptopunk.Derivation
  alias WarthogEx.Account
  alias WarthogEx.HDWallet

  @purpose 44
  @coin_type 2070
  @account 0

  defstruct [:root_node]

  @type t :: %__MODULE__{root_node: Cryptopunk.Key.t()}

  @doc """
  Create an `HDWallet` from a BIP-39 mnemonic phrase.

  Accepts 12, 15, 18, 21, or 24 words.
  """
  @spec from_mnemonic(String.t()) :: t()
  def from_mnemonic(mnemonic) when is_binary(mnemonic) do
    path = "m/#{@purpose}'/#{@coin_type}'/#{@account}'"
    {:ok, parsed_path} = Cryptopunk.Derivation.Path.parse_incomplete_path(path)
    seed = Cryptopunk.create_seed(mnemonic, "")
    root_node = Cryptopunk.master_key_from_seed(seed) |> Derivation.derive(parsed_path)
    %HDWallet{root_node: root_node}
  end

  @doc """
  Derive an account at the given index using path `0/{index}`.
  """
  @spec derive_account_at_index(t(), non_neg_integer()) :: Account.t()
  def derive_account_at_index(%HDWallet{} = wallet, index)
      when is_integer(index) and index >= 0 do
    derive_account_from_path(wallet, "0/#{index}")
  end

  @doc """
  Derive an account from a custom relative path.

  The path is treated as relative to the wallet's root (`m/44'/2070'/0'`).
  A leading `m/` is optional — pass either `"0/0"` or `"m/0/0"`.
  """
  @spec derive_account_from_path(t(), String.t()) :: Account.t()
  def derive_account_from_path(%HDWallet{root_node: root_node}, path) when is_binary(path) do
    full_path = ensure_master_prefix(path)
    {:ok, parsed} = Cryptopunk.Derivation.Path.parse_incomplete_path(full_path)
    child = Derivation.derive(root_node, parsed)
    Account.from_private_key!(child.key)
  end

  defp ensure_master_prefix(path) do
    case path do
      "m/" <> _ -> path
      "M/" <> _ -> path
      other -> "m/" <> other
    end
  end
end
