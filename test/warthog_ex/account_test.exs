defmodule WarthogEx.AccountTest do
  use ExUnit.Case, async: true

  alias WarthogEx.Account
  alias WarthogEx.Address

  test "Account.from_random generates a valid address" do
    account = Account.from_random()

    assert byte_size(account.private_key_hex) == 64
    assert byte_size(account.public_key_hex) == 66
    assert byte_size(account.address.hex) == 48

    assert Address.validate(account.address.hex)
  end

  test "Account.from_private_key_hex generates correct keys from a known private key" do
    private_key_hex = "966a71a98bb5d13e9116c0dffa3f1a7877e45c6f563897b96cfd5c59bf0803e0"
    assert {:ok, account} = Account.from_private_key_hex(private_key_hex)

    assert account.private_key_hex == private_key_hex

    assert account.public_key_hex ==
             "02916a397088159baf27b3ce1271a859e3e6ea27db913a94086423e5867994e705"

    assert account.address.hex == "3661579d61abde5837a8686dc4d65348a2fc61b1fe5f4093"
  end

  test "Account.from_private_key_hex!/1 raises on invalid input" do
    assert_raise ArgumentError, fn -> Account.from_private_key_hex!("too short") end
    assert_raise ArgumentError, fn -> Account.from_private_key_hex!(String.duplicate("z", 64)) end
  end

  test "Account.from_private_key_hex/1 returns :error for invalid input" do
    assert Account.from_private_key_hex("too short") == :error
    assert Account.from_private_key_hex(String.duplicate("z", 64)) == :error
    assert Account.from_private_key_hex(nil) == :error
  end

  test "Address.validate returns false for invalid checksum" do
    private_key_hex = "966a71a98bb5d13e9116c0dffa3f1a7877e45c6f563897b96cfd5c59bf0803e0"
    {:ok, account} = Account.from_private_key_hex(private_key_hex)
    address = account.address.hex
    invalid = binary_part(address, 0, 40) <> "00000000"

    refute Address.validate(invalid)
  end

  test "Address.validate returns false for wrong length" do
    refute Address.validate("abc123")

    refute Address.validate("a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9")
  end

  test "Address.validate returns false for non-hex string" do
    refute Address.validate(String.duplicate("g", 48))
  end

  test "sign/2 produces a 65-byte signature" do
    private_key_hex = "966a71a98bb5d13e9116c0dffa3f1a7877e45c6f563897b96cfd5c59bf0803e0"
    account = Account.from_private_key_hex!(private_key_hex)
    hash = :crypto.hash(:sha256, "hello world")

    assert {:ok, {_r, _s, recid, signature_hex}} = Account.sign(account, hash)
    assert byte_size(Base.decode16!(signature_hex, case: :lower)) == 65
    assert recid in 0..3
  end

  test "sign!/2 raises on wrong hash length" do
    account = Account.from_random()
    assert_raise ArgumentError, fn -> Account.sign!(account, "short") end
  end
end
