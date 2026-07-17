defmodule WarthogEx.LiquidityTest do
  use ExUnit.Case, async: true

  alias WarthogEx.Liquidity

  describe "parse/1" do
    test "parses 1.5 -> 150000000" do
      assert {:ok, %Liquidity{e8: 150_000_000}} = Liquidity.parse("1.5")
    end

    test "returns :error for too many decimals" do
      assert Liquidity.parse("1.123456789") == :error
    end
  end

  describe "parse!/1" do
    test "parses valid string" do
      assert %Liquidity{e8: 150_000_000} = Liquidity.parse!("1.5")
    end

    test "raises on invalid input" do
      assert_raise ArgumentError, fn -> Liquidity.parse!("1.123456789") end
    end
  end

  describe "from_e8/1" do
    test "creates Liquidity from valid E8" do
      assert {:ok, %Liquidity{e8: 100}} = Liquidity.from_e8(100)
    end

    test "returns :error for negative E8" do
      assert Liquidity.from_e8(-1) == :error
    end
  end

  describe "from_e8!/1" do
    test "creates Liquidity from valid E8" do
      assert %Liquidity{e8: 100} = Liquidity.from_e8!(100)
    end

    test "raises on negative E8" do
      assert_raise ArgumentError, fn -> Liquidity.from_e8!(-1) end
    end
  end
end
