defmodule WarthogEx.ParsedFundsTest do
  use ExUnit.Case, async: true

  alias WarthogEx.ParsedFunds

  describe "parse/1" do
    test "parses simple integer string" do
      assert {:ok, %ParsedFunds{val: 123, decimal_places: 0}} = ParsedFunds.parse("123")
    end

    test "parses decimal string" do
      assert {:ok, %ParsedFunds{val: 12345, decimal_places: 2}} = ParsedFunds.parse("123.45")
    end

    test "parses 1.123 -> (1123, 3)" do
      assert {:ok, %ParsedFunds{val: 1123, decimal_places: 3}} = ParsedFunds.parse("1.123")
    end

    test "parses 101.123000 -> (101123000, 6)" do
      assert {:ok, %ParsedFunds{val: 101_123_000, decimal_places: 6}} =
               ParsedFunds.parse("101.123000")
    end

    test "parses 101.1230001111 -> (1011230001111, 10)" do
      assert {:ok, %ParsedFunds{val: 101_123_000_1111, decimal_places: 10}} =
               ParsedFunds.parse("101.1230001111")
    end

    test "parses 101.00000000000000 -> (10100000000000000, 14)" do
      assert {:ok, %ParsedFunds{val: 10_100_000_000_000_000, decimal_places: 14}} =
               ParsedFunds.parse("101.00000000000000")
    end

    test "parses 123123101.001 -> (123123101001, 3)" do
      assert {:ok, %ParsedFunds{val: 123_123_101_001, decimal_places: 3}} =
               ParsedFunds.parse("123123101.001")
    end

    test "returns :error for invalid input" do
      assert ParsedFunds.parse("") == :error
      assert ParsedFunds.parse(".") == :error
      assert ParsedFunds.parse("abc") == :error
      assert ParsedFunds.parse("1.1.1") == :error
      assert ParsedFunds.parse(String.duplicate("1", 21)) == :error
      assert ParsedFunds.parse("18446744073709551616") == :error
    end

    test "returns :error for non-binary input" do
      assert ParsedFunds.parse(123) == :error
      assert ParsedFunds.parse(nil) == :error
    end
  end
end
