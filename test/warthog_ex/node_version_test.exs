defmodule WarthogEx.NodeVersionTest do
  use ExUnit.Case, async: true

  alias WarthogEx.NodeVersion

  @payload %{
    "name" => "v0.10.3 \"dd054a2\"",
    "major" => 0,
    "minor" => 10,
    "patch" => 3,
    "commit" => "dd054a2"
  }

  describe "parse/1" do
    test "reads the version fields" do
      assert {:ok, version} = NodeVersion.parse(@payload)

      assert %NodeVersion{
               name: "v0.10.3 \"dd054a2\"",
               major: 0,
               minor: 10,
               patch: 3,
               commit: "dd054a2"
             } = version
    end

    test "rejects a payload with a missing field" do
      for field <- ~w(name major minor patch commit) do
        payload = Map.delete(@payload, field)
        assert :error = NodeVersion.parse(payload)
      end
    end

    test "rejects a payload whose name is not a binary" do
      assert :error = NodeVersion.parse(%{@payload | "name" => 42})
    end

    test "rejects a payload whose commit is not a binary" do
      assert :error = NodeVersion.parse(%{@payload | "commit" => 42})
    end

    test "rejects a payload whose version numbers are not integers" do
      assert :error = NodeVersion.parse(%{@payload | "major" => "0"})
      assert :error = NodeVersion.parse(%{@payload | "minor" => "10"})
      assert :error = NodeVersion.parse(%{@payload | "patch" => "3"})
    end

    test "rejects a payload whose version numbers are negative" do
      assert :error = NodeVersion.parse(%{@payload | "major" => -1})
      assert :error = NodeVersion.parse(%{@payload | "minor" => -1})
      assert :error = NodeVersion.parse(%{@payload | "patch" => -1})
    end

    test "rejects a payload that is not a map" do
      assert :error = NodeVersion.parse(nil)
      assert :error = NodeVersion.parse("garbage")
      assert :error = NodeVersion.parse(42)
      assert :error = NodeVersion.parse([])
    end
  end

  describe "version/1" do
    test "returns the dotted triple" do
      assert {:ok, version} = NodeVersion.parse(@payload)
      assert NodeVersion.version(version) == "0.10.3"
    end
  end

  describe "parse!/1" do
    test "returns the version when the payload is well formed" do
      assert %NodeVersion{patch: 3} = NodeVersion.parse!(@payload)
    end

    test "raises when the payload is malformed" do
      assert_raise ArgumentError, fn -> NodeVersion.parse!(%{"name" => "v0.10.3"}) end
    end
  end
end
