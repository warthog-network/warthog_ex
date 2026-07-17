defmodule WarthogEx.FeeTest do
  use ExUnit.Case, async: true

  alias WarthogEx.CompactFee
  alias WarthogEx.RoundedFee
  alias WarthogEx.Wart

  describe "CompactFee.from_wart/2" do
    test "amount=0 returns smallest fee" do
      w = Wart.from_e8!(0)
      assert %CompactFee{exponent: 0, mantissa: 0} = CompactFee.from_wart(w, false)

      fee = CompactFee.from_wart(w, false) |> CompactFee.to_wart()
      assert %Wart{e8: 1} = fee

      w1 = Wart.from_e8!(1)
      fee1 = Wart.rounded_fee(w1, false)
      assert %RoundedFee{e8: 1} = fee1
    end
  end

  describe "fee rounding" do
    test "various amounts round correctly" do
      cases = [
        ".00003112",
        ".00013112",
        ".00113112",
        ".0111283",
        ".32",
        "5.12354",
        "10.02031022"
      ]

      for s <- cases do
        original = Wart.parse!(s)

        rounded_down = Wart.rounded_fee(original, false)
        assert rounded_down.e8 <= original.e8

        assert rounded_down.e8 ==
                 RoundedFee.to_wart(rounded_down) |> Wart.rounded_fee(false) |> Map.get(:e8)

        rounded_up = Wart.rounded_fee(original, true)
        assert rounded_up.e8 >= original.e8

        assert rounded_up.e8 ==
                 RoundedFee.to_wart(rounded_up) |> Wart.rounded_fee(true) |> Map.get(:e8)
      end
    end
  end

  describe "RoundedFee" do
    test "min/0 returns 1 E8" do
      assert %RoundedFee{e8: 1} = RoundedFee.min()
    end

    test "round-trip preserves fee" do
      fee = RoundedFee.from_e8!(123_456_789, false)
      assert fee.e8 == RoundedFee.to_wart(fee).e8
    end

    test "from_e8!/2 raises on negative E8" do
      assert_raise ArgumentError, fn -> RoundedFee.from_e8!(-1, false) end
    end
  end
end
