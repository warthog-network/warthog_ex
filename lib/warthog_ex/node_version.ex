defmodule WarthogEx.NodeVersion do
  @moduledoc """
  The version a node reports about itself.

  Every node family reports the same five fields, in the same flat shape:

    * `core/master` (main net) — `GET /tools/version`, nlohmann
      `to_json(PrintNodeVersion&)`
    * `core/dev` — `GET /tools/version`, nlohmann `to_json(PrintNodeVersion&)`
    * `core/defi` (test net) — `GET /version`, glaze `NodeVersion`

  So unlike `/chain/head`, which differs between API generations, the version
  payload needs no per-family handling. Only the URL differs, and that is the
  caller's business, not the parser's.

  ## Example

      iex> {:ok, version} = WarthogEx.NodeVersion.parse(%{
      ...>   "name" => "v0.10.3 \\"dd054a2\\"",
      ...>   "major" => 0,
      ...>   "minor" => 10,
      ...>   "patch" => 3,
      ...>   "commit" => "dd054a2"
      ...> })
      iex> WarthogEx.NodeVersion.version(version)
      "0.10.3"
  """

  alias WarthogEx.NodeVersion

  @type t :: %__MODULE__{
          name: String.t(),
          major: non_neg_integer(),
          minor: non_neg_integer(),
          patch: non_neg_integer(),
          commit: String.t()
        }

  defstruct [:name, :major, :minor, :patch, :commit]

  @doc """
  Read the version out of a node response.

  Returns `{:ok, %NodeVersion{}}` if the payload carries every field with the
  right type, otherwise `:error`.
  """
  @spec parse(term()) :: {:ok, t()} | :error
  def parse(data) when is_map(data) do
    with %{"name" => name} when is_binary(name) <- data,
         %{"commit" => commit} when is_binary(commit) <- data,
         %{"major" => major} when is_integer(major) and major >= 0 <- data,
         %{"minor" => minor} when is_integer(minor) and minor >= 0 <- data,
         %{"patch" => patch} when is_integer(patch) and patch >= 0 <- data do
      {:ok, %NodeVersion{name: name, major: major, minor: minor, patch: patch, commit: commit}}
    else
      _ -> :error
    end
  end

  def parse(_data), do: :error

  @doc """
  Like `parse/1` but raises on invalid input.
  """
  @spec parse!(term()) :: t()
  def parse!(data) do
    case parse(data) do
      {:ok, version} ->
        version

      :error ->
        raise ArgumentError, "invalid node version response"
    end
  end

  @doc """
  The version as a dotted triple, e.g. `"0.10.3"`.

  This is the numeric form, without the `v` prefix and without the commit
  hash. It is what a version comparison wants.
  """
  @spec version(t()) :: String.t()
  def version(%__MODULE__{major: major, minor: minor, patch: patch}) do
    "#{major}.#{minor}.#{patch}"
  end
end
