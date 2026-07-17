defmodule WarthogEx.HDWalletTest do
  use ExUnit.Case, async: true

  alias WarthogEx.Account
  alias WarthogEx.HDWallet

  @mnemonic "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

  test "HDWallet.from_mnemonic returns a valid Account" do
    wallet = HDWallet.from_mnemonic(@mnemonic)
    account = HDWallet.derive_account_at_index(wallet, 0)

    assert byte_size(account.address.hex) == 48
    assert byte_size(account.private_key_hex) == 64
  end

  test "HDWallet.derive_account_at_index(0) != derive_account(1)" do
    wallet = HDWallet.from_mnemonic(@mnemonic)
    a0 = HDWallet.derive_account_at_index(wallet, 0)
    a1 = HDWallet.derive_account_at_index(wallet, 1)

    assert a0.address.hex != a1.address.hex
  end

  test "HDWallet full-path derivation matches index method" do
    wallet = HDWallet.from_mnemonic(@mnemonic)
    a_from_index = HDWallet.derive_account_at_index(wallet, 0)
    a_from_path = HDWallet.derive_account_from_path(wallet, "0/0")

    assert a_from_index.address.hex == a_from_path.address.hex
  end

  test "derivation returns Account structs" do
    wallet = HDWallet.from_mnemonic(@mnemonic)
    account = HDWallet.derive_account_at_index(wallet, 0)
    assert %Account{} = account
  end
end
