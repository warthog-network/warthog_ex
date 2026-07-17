defmodule WarthogEx.PriceTest do
  use ExUnit.Case, async: true

  alias WarthogEx.Price
  alias WarthogEx.TokenDecimals

  describe "from_double_internal/2" do
    test "rejects zero, negative, infinity, and NaN" do
      assert Price.from_double_internal(0.0) == :error
      assert Price.from_double_internal(0) == :error
      assert Price.from_double_internal(-1.0) == :error
      assert Price.from_double_internal(-0.5) == :error
      assert Price.from_double_internal(:infinity) == :error
      assert Price.from_double_internal(:"-infinity") == :error
      assert Price.from_double_internal(:nan) == :error
    end
  end

  describe "from_double_internal!/2" do
    test "raises on invalid input" do
      assert_raise ArgumentError, fn -> Price.from_double_internal!(0.0) end
      assert_raise ArgumentError, fn -> Price.from_double_internal!(:nan) end
    end
  end

  describe "roundtrip from_double_internal -> to_double_raw" do
    for input <- [
          0.0000001354,
          0.000001345,
          0.000016574,
          0.00012043,
          0.0011239,
          0.02341,
          0.1812,
          0.5123,
          1.813,
          2.5213,
          16.430,
          194.75,
          1834.5678,
          12_093,
          234_091,
          9_582_389,
          190_123_900,
          9_230_942_914
        ] do
      test "roundtrip for #{input}" do
        input = unquote(input)
        price = Price.from_double_internal!(input)
        output = price |> Price.to_double_raw()
        assert abs(1 - output / input) * 100 < 0.01
      end
    end
  end

  describe "from_hex/1 and to_hex/1" do
    test "roundtrips a known price" do
      hex = "c0e74d"
      assert {:ok, price} = Price.from_hex(hex)
      assert Price.to_hex(price) == hex
    end

    test "returns :error for wrong length" do
      assert Price.from_hex("abc") == :error
    end

    test "returns :error for invalid hex" do
      assert Price.from_hex("zzzzzz") == :error
    end

    test "accepts exponent at internal maximum (127)" do
      assert {:ok, %Price{mantissa: 0xFFFF, exponent: 127}} = Price.from_hex("ffff7f")
    end

    test "rejects exponents above the internal maximum (>= 128)" do
      assert Price.from_hex("ffff80") == :error
      assert Price.from_hex("ffffff") == :error
      assert Price.from_hex("800080") == :error
    end

    test "rejects mantissas outside the normalized range" do
      assert Price.from_hex("7fff00") == :error
      assert Price.from_hex("000000") == :error
    end

    test "from_hex!/1 raises on invalid hex" do
      assert_raise ArgumentError, fn -> Price.from_hex!("zzzzzz") end
      assert %Price{} = Price.from_hex!("c0e74d")
    end
  end

  describe "max/0" do
    test "returns maximum possible price" do
      %Price{mantissa: 0xFFFF, exponent: 127} = Price.max()
    end
  end

  describe "from_mantissa_exponent/2" do
    test "creates a valid price" do
      assert {:ok, %Price{mantissa: 0x8000, exponent: 63}} =
               Price.from_mantissa_exponent(0x8000, 0)
    end

    test "rejects invalid mantissa" do
      assert Price.from_mantissa_exponent(0x7000, 0) == :error
    end

    test "from_mantissa_exponent!/2 raises on invalid input" do
      assert_raise ArgumentError, fn -> Price.from_mantissa_exponent!(0x7000, 0) end
    end
  end

  describe "from_number_decimals/3" do
    test "respects base decimals" do
      assert {:ok, p} = Price.from_number_decimals(1.5, TokenDecimals.wart(), false)
      assert is_struct(p, Price)
    end

    test "from_number_decimals!/3 raises on invalid input" do
      assert_raise ArgumentError, fn ->
        Price.from_number_decimals!(-1.0, TokenDecimals.wart())
      end
    end
  end
end
