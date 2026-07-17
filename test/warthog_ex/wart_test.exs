defmodule WarthogEx.WartTest do
  use ExUnit.Case, async: true

  alias WarthogEx.Wart

  describe "parse/1" do
    test "parses 1.123 -> 112300000" do
      assert {:ok, %Wart{e8: 112_300_000}} = Wart.parse("1.123")
    end

    test "returns :error for too many decimals" do
      assert Wart.parse("1.123456789") == :error
    end
  end

  describe "parse!/1" do
    test "parses valid string" do
      assert %Wart{e8: 112_300_000} = Wart.parse!("1.123")
    end

    test "raises on invalid input" do
      assert_raise ArgumentError, fn -> Wart.parse!("1.123456789") end
    end
  end

  describe "from_e8/1" do
    test "creates Wart from valid E8" do
      assert {:ok, %Wart{e8: 100_000_000}} = Wart.from_e8(100_000_000)
    end

    test "returns :error for negative E8" do
      assert Wart.from_e8(-1) == :error
    end
  end

  describe "from_e8!/1" do
    test "creates Wart from valid E8" do
      assert %Wart{e8: 100_000_000} = Wart.from_e8!(100_000_000)
    end

    test "raises on negative E8" do
      assert_raise ArgumentError, fn -> Wart.from_e8!(-1) end
    end
  end
end
