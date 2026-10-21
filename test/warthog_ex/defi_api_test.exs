defmodule WarthogEx.DeFiApiTest do
  use ExUnit.Case, async: true

  alias WarthogEx.Api
  alias WarthogEx.DeFiApi

  describe "new" do
    test "without a URL uses the first known DeFi node" do
      api = DeFiApi.new()
      assert api.base_url == hd(Api.known_nodes_defi())
    end

    test "with explicit URL overrides the default" do
      api = DeFiApi.new("http://127.0.0.1:3101")
      assert api.base_url == "http://127.0.0.1:3101"
    end
  end

  describe "known_nodes_defi/0" do
    test "returns a non-empty list of public http(s) URLs" do
      nodes = Api.known_nodes_defi()
      assert is_list(nodes)
      assert length(nodes) > 0
      assert Enum.all?(nodes, &String.starts_with?(&1, ["http://", "https://"]))
    end
  end

  test "the two node families have separate node lists" do
    refute Api.known_nodes_legacy() == Api.known_nodes_defi()
  end
end
