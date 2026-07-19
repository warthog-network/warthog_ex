defmodule WarthogEx.AccountTest do
  use ExUnit.Case, async: true

  import Bitwise

  alias WarthogEx.Account
  alias WarthogEx.Address

  @private_key_hex "966a71a98bb5d13e9116c0dffa3f1a7877e45c6f563897b96cfd5c59bf0803e0"
  @public_key_hex "02916a397088159baf27b3ce1271a859e3e6ea27db913a94086423e5867994e705"
  @address_hex "3661579d61abde5837a8686dc4d65348a2fc61b1fe5f4093"

  defp known_account, do: Account.from_private_key_hex!(@private_key_hex)

  test "Account.from_random generates a valid address" do
    account = Account.from_random()

    assert byte_size(account.private_key_hex) == 64
    assert byte_size(account.public_key_hex) == 66
    assert byte_size(account.address.hex) == 48

    assert Address.validate(account.address.hex)
  end

  test "Account.from_private_key_hex generates correct keys from a known private key" do
    assert {:ok, account} = Account.from_private_key_hex(@private_key_hex)

    assert account.private_key_hex == @private_key_hex
    assert account.public_key_hex == @public_key_hex
    assert account.address.hex == @address_hex
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
    {:ok, account} = Account.from_private_key_hex(@private_key_hex)
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

  test "sign_bytes/2 returns a valid Signature65 tuple" do
    account = known_account()
    assert {:ok, {_r, _s, recid, signature_hex}} = Account.sign_bytes(account, "hello")

    assert byte_size(Base.decode16!(signature_hex, case: :lower)) == 65
    assert recid in 0..3
    assert String.length(signature_hex) == 130
  end

  test "sign_bytes/2 is deterministic for the same input" do
    account = known_account()
    assert {:ok, sig1} = Account.sign_bytes(account, "hello")
    assert {:ok, sig2} = Account.sign_bytes(account, "hello")

    assert sig1 == sig2
  end

  test "sign_bytes/2 works on empty input" do
    account = known_account()
    assert {:ok, {_r, _s, recid, signature_hex}} = Account.sign_bytes(account, "")
    assert String.length(signature_hex) == 130
    assert recid in 0..3
  end

  test "sign_bytes/2 returns :error for non-binary input" do
    account = known_account()
    assert Account.sign_bytes(account, 123) == :error
    assert Account.sign_bytes(account, nil) == :error
  end

  test "sign_bytes!/2 raises on non-binary input" do
    account = known_account()
    assert_raise ArgumentError, fn -> Account.sign_bytes!(account, 123) end
  end

  test "recover_public_key/2 round-trips a sign_bytes signature (tuple form)" do
    account = known_account()
    {:ok, {_r, _s, recid, signature_hex}} = Account.sign_bytes(account, "hello")

    # Build the tuple form from the hex signature for the recovery call.
    <<r::binary-size(32), s::binary-size(32), _::binary-size(1)>> =
      Base.decode16!(signature_hex, case: :lower)

    assert {:ok, recovered} = Account.recover_public_key("hello", {r, s, recid})
    assert recovered == @public_key_hex
  end

  test "recover_address/2 round-trips a sign_bytes signature" do
    account = known_account()
    {:ok, {_r, _s, _recid, signature_hex}} = Account.sign_bytes(account, "hello")

    assert {:ok, recovered} = Account.recover_address("hello", signature_hex)
    assert recovered.hex == @address_hex
  end

  test "recover_public_key/2 returns a different key for a tampered message" do
    account = known_account()
    {:ok, {_r, _s, _recid, signature_hex}} = Account.sign_bytes(account, "hello")

    assert {:ok, recovered} = Account.recover_public_key("hellp", signature_hex)
    assert recovered != @public_key_hex
  end

  test "recover_public_key/2 is sensitive to the recovery id" do
    account = known_account()
    {:ok, {_r, _s, recid, signature_hex}} = Account.sign_bytes(account, "hello")

    <<r::binary-size(32), s::binary-size(32), _::binary-size(1)>> =
      Base.decode16!(signature_hex, case: :lower)

    flipped_recid = bxor(recid, 1)
    flipped_sig = Base.encode16(r <> s <> <<flipped_recid>>, case: :lower)

    case Account.recover_public_key("hello", flipped_sig) do
      {:ok, recovered} ->
        assert recovered != @public_key_hex

      :error ->
        # Recovery failure is also acceptable — flipped recid may not
        # correspond to any valid point on the curve for this signature.
        :ok
    end
  end

  test "recover_public_key/2 accepts the 130-char hex signature string" do
    account = known_account()
    {:ok, {_r, _s, _recid, signature_hex}} = Account.sign_bytes(account, "hello")

    assert {:ok, recovered} = Account.recover_public_key("hello", signature_hex)
    assert recovered == @public_key_hex
  end

  test "recover_public_key/2 returns :error on invalid signature" do
    assert Account.recover_public_key("hello", "abcd") == :error
    assert Account.recover_public_key("hello", String.duplicate("z", 130)) == :error

    assert Account.recover_public_key("hello", {"bad", "bad", 5}) == :error
  end

  test "recover_public_key!/2 and recover_address!/2 raise on failure" do
    assert_raise ArgumentError, fn -> Account.recover_public_key!("hello", "abcd") end
    assert_raise ArgumentError, fn -> Account.recover_address!("hello", "abcd") end
  end
end
