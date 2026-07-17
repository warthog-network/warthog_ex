defmodule WarthogEx.TokenDecimalsTest do
  use ExUnit.Case, async: true

  alias WarthogEx.TokenDecimals

  describe "new/1" do
    test "accepts valid decimals 0..18" do
      for n <- 0..18 do
        assert {:ok, %TokenDecimals{decimals: ^n}} = TokenDecimals.new(n)
      end
    end

    test "rejects invalid decimals" do
      assert TokenDecimals.new(-1) == :error
      assert TokenDecimals.new(19) == :error
      assert TokenDecimals.new("8") == :error
      assert TokenDecimals.new(nil) == :error
    end
  end

  describe "new!/1" do
    test "accepts valid decimals" do
      assert %TokenDecimals{decimals: 8} = TokenDecimals.new!(8)
    end

    test "raises on invalid decimals" do
      assert_raise ArgumentError, fn -> TokenDecimals.new!(-1) end
      assert_raise ArgumentError, fn -> TokenDecimals.new!(19) end
    end
  end

  describe "presets" do
    test "wart returns 8 decimals" do
      assert %TokenDecimals{decimals: 8} = TokenDecimals.wart()
    end

    test "liquidity returns 8 decimals" do
      assert %TokenDecimals{decimals: 8} = TokenDecimals.liquidity()
    end
  end
end
