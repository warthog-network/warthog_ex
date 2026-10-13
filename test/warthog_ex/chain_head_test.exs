defmodule WarthogEx.ChainHeadTest do
  use ExUnit.Case, async: true

  alias WarthogEx.ChainHead
  alias WarthogEx.ChainPin

  @hash String.duplicate("a", 64)

  describe "parse/2 (V1 API)" do
    test "normalizes the flat payload" do
      assert {:ok, head} =
               ChainHead.parse(
                 %{
                   "hash" => @hash,
                   "height" => 100,
                   "pinHash" => @hash,
                   "pinHeight" => 64,
                   "synced" => true
                 },
                 :v1
               )

      assert %ChainHead{
               pin: %ChainPin{pin_hash: @hash, pin_height: 64},
               hash: @hash,
               height: 100,
               synced: true
             } = head
    end

    test "rejects a V2 payload declared as V1" do
      assert :error =
               ChainHead.parse(
                 %{"chainHead" => %{"hash" => @hash, "height" => 1, "pinHash" => @hash, "pinHeight" => 0}},
                 :v1
               )
    end
  end

  describe "parse/2 (V2 API)" do
    test "normalizes the nested payload and reads synced from the root" do
      assert {:ok, head} =
               ChainHead.parse(
                 %{
                   "chainHead" => %{
                     "hash" => @hash,
                     "height" => 100,
                     "pinHash" => @hash,
                     "pinHeight" => 64
                   },
                   "synced" => true
                 },
                 :v2
               )

      assert head.pin.pin_height == 64
      assert head.hash == @hash
      assert head.height == 100
      assert head.synced == true
    end

    test "ignores a synced key nested inside chainHead" do
      assert {:ok, head} =
               ChainHead.parse(
                 %{
                   "chainHead" => %{
                     "hash" => @hash,
                     "height" => 1,
                     "pinHash" => @hash,
                     "pinHeight" => 0,
                     "synced" => true
                   }
                 },
                 :v2
               )

      assert head.synced == false
    end

    test "rejects a V1 payload declared as V2" do
      assert :error =
               ChainHead.parse(
                 %{"hash" => @hash, "height" => 1, "pinHash" => @hash, "pinHeight" => 0},
                 :v2
               )
    end
  end

  describe "parse/2 (incomplete payloads)" do
    test "rejects a payload with no hash" do
      assert :error =
               ChainHead.parse(%{"height" => 1, "pinHash" => @hash, "pinHeight" => 0}, :v1)
    end

    test "rejects a payload with no height" do
      assert :error =
               ChainHead.parse(%{"hash" => @hash, "pinHash" => @hash, "pinHeight" => 0}, :v1)
    end

    test "rejects a payload whose height is not an integer" do
      assert :error =
               ChainHead.parse(
                 %{"hash" => @hash, "height" => "100", "pinHash" => @hash, "pinHeight" => 0},
                 :v1
               )
    end

    test "rejects a payload with a malformed pin" do
      assert :error =
               ChainHead.parse(
                 %{"hash" => @hash, "height" => 1, "pinHash" => @hash, "pinHeight" => 3},
                 :v1
               )
    end
  end

  describe "parse!/2" do
    test "raises when the payload does not match the version" do
      assert_raise ArgumentError, fn ->
        ChainHead.parse!(
          %{"chainHead" => %{"hash" => @hash, "height" => 1, "pinHash" => @hash, "pinHeight" => 0}},
          :v1
        )
      end
    end
  end
end