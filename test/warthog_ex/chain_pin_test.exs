defmodule WarthogEx.ChainPinTest do
  use ExUnit.Case, async: true

  alias WarthogEx.ChainPin

  @hash String.duplicate("a", 64)

  describe "validate/2" do
    test "accepts a well-formed pin" do
      assert ChainPin.validate(@hash, 0)
      assert ChainPin.validate(@hash, 32)
      assert ChainPin.validate(@hash, 320)
    end

    test "rejects a pin height that is not a multiple of 32" do
      refute ChainPin.validate(@hash, 1)
      refute ChainPin.validate(@hash, 31)
      refute ChainPin.validate(@hash, 321)
    end

    test "rejects a negative pin height" do
      refute ChainPin.validate(@hash, -32)
    end

    test "rejects a hash that is not 64 hex characters" do
      refute ChainPin.validate(String.duplicate("a", 63), 32)
      refute ChainPin.validate(String.duplicate("a", 65), 32)
      refute ChainPin.validate("", 32)
    end

    test "rejects non-string hashes and non-integer heights" do
      refute ChainPin.validate(123, 32)
      refute ChainPin.validate(@hash, "32")
      refute ChainPin.validate(@hash, 32.0)
      refute ChainPin.validate(nil, nil)
    end
  end

  describe "parse/2 (V1 API)" do
    test "reads the pin from the top level" do
      assert {:ok, %ChainPin{pin_hash: @hash, pin_height: 320}} =
               ChainPin.parse(%{"pinHash" => @hash, "pinHeight" => 320, "synced" => true}, :v1)
    end

    test "rejects a V2 payload declared as V1" do
      assert :error =
               ChainPin.parse(%{"chainHead" => %{"pinHash" => @hash, "pinHeight" => 320}}, :v1)
    end

    test "rejects a payload missing the pin fields" do
      assert :error = ChainPin.parse(%{"hash" => @hash, "height" => 1}, :v1)
    end
  end

  describe "parse/2 (V2 API)" do
    test "reads the pin from chainHead" do
      assert {:ok, %ChainPin{pin_hash: @hash, pin_height: 320}} =
               ChainPin.parse(
                 %{
                   "chainHead" => %{"pinHash" => @hash, "pinHeight" => 320},
                   "synced" => true
                 },
                 :v2
               )
    end

    test "rejects a V1 payload declared as V2" do
      assert :error = ChainPin.parse(%{"pinHash" => @hash, "pinHeight" => 320}, :v2)
    end

    test "rejects a payload whose chainHead is not a map" do
      assert :error = ChainPin.parse(%{"chainHead" => "nope"}, :v2)
    end
  end

  describe "parse/2 (bad input)" do
    test "rejects an unknown version" do
      assert :error = ChainPin.parse(%{"pinHash" => @hash, "pinHeight" => 320}, :v3)
    end

    test "rejects a non-map payload" do
      assert :error = ChainPin.parse(nil, :v1)
      assert :error = ChainPin.parse("chainHead", :v2)
    end
  end

  describe "parse!/2" do
    test "returns the pin when the payload matches" do
      assert %ChainPin{pin_height: 320} =
               ChainPin.parse!(%{"pinHash" => @hash, "pinHeight" => 320}, :v1)
    end

    test "raises when the payload does not match" do
      assert_raise ArgumentError, fn ->
        ChainPin.parse!(%{"chainHead" => %{"pinHash" => @hash, "pinHeight" => 320}}, :v1)
      end
    end
  end

  test "pin_height_multiple/0 is 32" do
    assert ChainPin.pin_height_multiple() == 32
  end
end