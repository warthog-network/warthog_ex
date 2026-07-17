defmodule WarthogEx.NonceIdTest do
  use ExUnit.Case, async: true

  alias WarthogEx.NonceId

  describe "validate/1" do
    test "returns true for valid 32-bit unsigned integers" do
      assert NonceId.validate(0)
      assert NonceId.validate(1)
      assert NonceId.validate(0xFFFFFFFF)
      assert NonceId.validate(12345)
    end

    test "returns false for out-of-range values" do
      refute NonceId.validate(-1)
      refute NonceId.validate(0x100000000)
    end

    test "returns false for non-integers" do
      refute NonceId.validate("123")
      refute NonceId.validate(:atom)
      refute NonceId.validate(nil)
    end
  end

  describe "from_number/1" do
    test "creates NonceId from valid number" do
      assert {:ok, %NonceId{value: 12345}} = NonceId.from_number(12345)
    end

    test "returns :error for invalid number" do
      assert NonceId.from_number(-1) == :error
      assert NonceId.from_number(0x100000000) == :error
    end
  end

  describe "from_number!/1" do
    test "creates NonceId from valid number" do
      assert %NonceId{value: 12345} = NonceId.from_number!(12345)
    end

    test "raises on invalid number" do
      assert_raise ArgumentError, fn -> NonceId.from_number!(-1) end
      assert_raise ArgumentError, fn -> NonceId.from_number!(0x100000000) end
    end
  end

  describe "random/0" do
    test "generates a NonceId within valid range" do
      nonce = NonceId.random()
      assert %NonceId{} = nonce
      assert NonceId.validate(nonce.value)
    end
  end
end
