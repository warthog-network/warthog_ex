defmodule WarthogEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :warthog_ex,
      version: "0.1.1",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      description: description(),
      source_url: "https://github.com/warthog-network/warthog-ex",
      docs: [
        main: "readme",
        extras: ["README.md"]
      ],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto, :public_key]
    ]
  end

  defp description do
    """
    An Elixir library for the Warthog cryptocurrency.

    Provides type-safe primitives for building and submitting transactions
    on the Warthog network. This is the Elixir port of the `warthog-ts`
    TypeScript library, supporting the full native DeFi transaction set
    (`wartTransfer`, `tokenTransfer`, `assetCreation`, `limitSwap`,
    `liquidityDeposit`, `liquidityWithdrawal`, `cancelation`).
    """
  end

  defp deps do
    [
      {:ex_secp256k1, "~> 0.8"},
      {:cryptopunk, "~> 0.7"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.4"}
    ]
  end
end
