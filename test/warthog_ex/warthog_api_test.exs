defmodule WarthogEx.WarthogApiTest do
  use ExUnit.Case, async: true

  alias WarthogEx.WarthogApi

  describe "new/1" do
    test "without args uses the first known_nodes() entry (public testnet)" do
      api = WarthogApi.new()
      assert api.base_url == hd(WarthogApi.known_nodes())
    end

    test "with explicit URL overrides the default" do
      api = WarthogApi.new("http://127.0.0.1:3100")
      assert api.base_url == "http://127.0.0.1:3100"
    end
  end

  describe "known_nodes/0" do
    test "returns a non-empty list of public http(s) URLs" do
      nodes = WarthogApi.known_nodes()
      assert is_list(nodes)
      assert length(nodes) > 0
      assert Enum.all?(nodes, &String.starts_with?(&1, ["http://", "https://"]))
    end
  end
end