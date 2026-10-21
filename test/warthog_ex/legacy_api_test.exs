defmodule WarthogEx.LegacyApiTest do
  use ExUnit.Case, async: true

  alias WarthogEx.Api
  alias WarthogEx.LegacyApi

  describe "new" do
    test "without a URL uses the first known legacy node" do
      api = LegacyApi.new()
      assert api.base_url == hd(Api.known_nodes_legacy())
    end

    test "with explicit URL overrides the default" do
      api = LegacyApi.new("http://127.0.0.1:3100")
      assert api.base_url == "http://127.0.0.1:3100"
    end
  end

  describe "known_nodes_legacy/0" do
    test "returns a non-empty list of public http(s) URLs" do
      nodes = Api.known_nodes_legacy()
      assert is_list(nodes)
      assert length(nodes) > 0
      assert Enum.all?(nodes, &String.starts_with?(&1, ["http://", "https://"]))
    end
  end
end
