defmodule WarthogEx.AddressTest do
  use ExUnit.Case, async: true

  alias WarthogEx.Address

  describe "from_hex/1" do
    test "parses a valid 48-character address with checksum" do
      hex = "3661579d61abde5837a8686dc4d65348a2fc61b1fe5f4093"
      assert {:ok, %Address{hex: ^hex}} = Address.from_hex(hex)
    end

    test "returns :error for wrong length" do
      assert Address.from_hex("abc123") == :error

      assert Address.from_hex("a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9") ==
               :error
    end

    test "returns :error for non-hex string" do
      assert Address.from_hex(String.duplicate("g", 48)) == :error
    end

    test "returns :error for invalid checksum" do
      assert Address.from_hex(String.duplicate("0", 40) <> "00000000") == :error
    end
  end

  describe "from_hex!/1" do
    test "returns valid address" do
      hex = "3661579d61abde5837a8686dc4d65348a2fc61b1fe5f4093"
      assert %Address{hex: ^hex} = Address.from_hex!(hex)
    end

    test "raises on invalid address" do
      assert_raise ArgumentError, fn -> Address.from_hex!("bad") end
    end
  end

  describe "from_raw/1" do
    test "computes checksum from 40-char hex" do
      assert {:ok, %Address{hex: hex}} = Address.from_raw(String.duplicate("0", 40))
      assert byte_size(hex) == 48
    end

    test "returns :error for wrong length" do
      assert Address.from_raw("abc123") == :error
    end
  end

  describe "from_raw!/1" do
    test "returns valid address" do
      assert %Address{} = Address.from_raw!(String.duplicate("0", 40))
    end

    test "raises on invalid input" do
      assert_raise ArgumentError, fn -> Address.from_raw!("bad") end
    end
  end

  describe "validate/1" do
    test "returns true for valid checksummed address" do
      hex = "3661579d61abde5837a8686dc4d65348a2fc61b1fe5f4093"
      assert Address.validate(hex)
    end

    test "returns false for invalid checksum" do
      hex = "3661579d61abde5837a8686dc4d65348a2fc61b1fe5f4093"
      invalid = binary_part(hex, 0, 40) <> "00000000"
      refute Address.validate(invalid)
    end

    test "returns false for wrong length" do
      refute Address.validate("abc123")

      refute Address.validate("a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9")
    end

    test "returns false for non-hex string" do
      refute Address.validate(String.duplicate("g", 48))
    end
  end
end
