defmodule WarthogEx.WarthogApiTest do
  use ExUnit.Case, async: true

  alias WarthogEx.WarthogApi

  describe "new" do
    test "without a URL uses the first known_nodes() entry" do
      api = WarthogApi.new(:v1)
      assert api.base_url == hd(WarthogApi.known_nodes())
      assert api.version == :v1
    end

    test "with explicit URL overrides the default" do
      api = WarthogApi.new(:v2, "http://127.0.0.1:3200")
      assert api.base_url == "http://127.0.0.1:3200"
      assert api.version == :v2
    end

    test "the version is required and must be a known generation" do
      # `new/0` no longer exists, and the old positional URL form is now a
      # bad generation, so both fail loudly rather than mis-parsing.
      # Called via apply/3 so the compiler does not warn on the missing new/0.
      assert_raise UndefinedFunctionError, fn -> apply(WarthogApi, :new, []) end
      assert_raise FunctionClauseError, fn -> WarthogApi.new("http://127.0.0.1:3100") end
      assert_raise FunctionClauseError, fn -> WarthogApi.new(:v3) end
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