defmodule WarthogEx.FundsTest do
  use ExUnit.Case, async: true

  alias WarthogEx.Funds
  alias WarthogEx.ParsedFunds
  alias WarthogEx.TokenDecimals

  describe "parse/2" do
    test "parses valid string with 4 decimals" do
      assert {:ok, %Funds{amount: 11_230}} = Funds.parse("1.123", %TokenDecimals{decimals: 4})
    end

    test "returns :error when too many decimals" do
      assert Funds.parse("1.123", %TokenDecimals{decimals: 2}) == :error
    end
  end

  describe "parse!/2" do
    test "parses valid string" do
      assert %Funds{amount: 11_230} = Funds.parse!("1.123", %TokenDecimals{decimals: 4})
    end

    test "raises on invalid string" do
      assert_raise ArgumentError, fn -> Funds.parse!("1.123", %TokenDecimals{decimals: 2}) end
    end
  end

  describe "from_parsed_funds/2" do
    test "converts parsed funds with 4 decimals" do
      pf = %ParsedFunds{val: 1123, decimal_places: 3}

      assert {:ok, %Funds{amount: 11_230}} =
               Funds.from_parsed_funds(pf, %TokenDecimals{decimals: 4})
    end

    test "parses 1.123 with various decimals" do
      pf = ParsedFunds.parse!("1.123")
      assert Funds.from_parsed_funds(pf, %TokenDecimals{decimals: 0}) == :error

      assert {:ok, %Funds{amount: 11_230}} =
               Funds.from_parsed_funds(pf, %TokenDecimals{decimals: 4})

      assert {:ok, %Funds{amount: 1_123_000_000_000}} =
               Funds.from_parsed_funds(pf, %TokenDecimals{decimals: 12})

      assert {:ok, %Funds{amount: 11_230_000_000_000_000}} =
               Funds.from_parsed_funds(pf, %TokenDecimals{decimals: 16})
    end

    test "parses 101.123000 with various decimals" do
      pf = ParsedFunds.parse!("101.123000")
      assert Funds.from_parsed_funds(pf, %TokenDecimals{decimals: 0}) == :error
      assert Funds.from_parsed_funds(pf, %TokenDecimals{decimals: 4}) == :error

      assert {:ok, %Funds{amount: 101_123_000_000_000}} =
               Funds.from_parsed_funds(pf, %TokenDecimals{decimals: 12})

      assert {:ok, %Funds{amount: 1_011_230_000_000_000_000}} =
               Funds.from_parsed_funds(pf, %TokenDecimals{decimals: 16})
    end

    test "parses 101.1230001111 with various decimals" do
      pf = ParsedFunds.parse!("101.1230001111")
      assert Funds.from_parsed_funds(pf, %TokenDecimals{decimals: 0}) == :error
      assert Funds.from_parsed_funds(pf, %TokenDecimals{decimals: 4}) == :error

      assert {:ok, %Funds{amount: 101_123_000_111_100}} =
               Funds.from_parsed_funds(pf, %TokenDecimals{decimals: 12})

      assert {:ok, %Funds{amount: 1_011_230_001_111_000_000}} =
               Funds.from_parsed_funds(pf, %TokenDecimals{decimals: 16})
    end

    test "parses 101.00000000000000 with various decimals" do
      pf = ParsedFunds.parse!("101.00000000000000")
      assert Funds.from_parsed_funds(pf, %TokenDecimals{decimals: 0}) == :error
      assert Funds.from_parsed_funds(pf, %TokenDecimals{decimals: 4}) == :error
      assert Funds.from_parsed_funds(pf, %TokenDecimals{decimals: 12}) == :error

      assert {:ok, %Funds{amount: 1_010_000_000_000_000_000}} =
               Funds.from_parsed_funds(pf, %TokenDecimals{decimals: 16})
    end

    test "parses 123123101.001 with various decimals" do
      pf = ParsedFunds.parse!("123123101.001")
      assert Funds.from_parsed_funds(pf, %TokenDecimals{decimals: 0}) == :error

      assert {:ok, %Funds{amount: 1_231_231_010_010}} =
               Funds.from_parsed_funds(pf, %TokenDecimals{decimals: 4})

      assert Funds.from_parsed_funds(pf, %TokenDecimals{decimals: 12}) == :error
      assert Funds.from_parsed_funds(pf, %TokenDecimals{decimals: 16}) == :error
    end
  end
end
