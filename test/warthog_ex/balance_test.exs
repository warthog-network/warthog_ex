defmodule WarthogEx.BalanceTest do
  use ExUnit.Case, async: true

  alias WarthogEx.DeFiWartBalance
  alias WarthogEx.TokenBalance

  describe "DeFiWartBalance" do
    test "parses the three amounts a node reports" do
      data = %{
        "wart" => %{
          "total" => %{"str" => "10.00000000", "E8" => 1_000_000_000},
          "locked" => %{"str" => "2.00000000", "E8" => 200_000_000},
          "mempool" => %{"str" => "1.00000000", "E8" => 100_000_000}
        }
      }

      assert {:ok, balance} = DeFiWartBalance.parse(data)
      assert balance.total.e8 == 1_000_000_000
      assert balance.locked.e8 == 200_000_000
      assert balance.mempool.e8 == 100_000_000
    end

    test "free is the total minus the two locked parts" do
      data = %{
        "wart" => %{
          "total" => %{"str" => "10.00000000"},
          "locked" => %{"str" => "2.00000000"},
          "mempool" => %{"str" => "1.00000000"}
        }
      }

      assert {:ok, balance} = DeFiWartBalance.parse(data)
      assert {:ok, free} = DeFiWartBalance.free(balance)
      assert free.e8 == 700_000_000
    end

    test "a balance that does not add up is rejected" do
      data = %{
        "wart" => %{
          "total" => %{"str" => "1.00000000"},
          "locked" => %{"str" => "2.00000000"},
          "mempool" => %{"str" => "0.00000000"}
        }
      }

      assert DeFiWartBalance.parse(data) == :error
    end

    test "a malformed payload is rejected" do
      assert DeFiWartBalance.parse(%{}) == :error
      assert DeFiWartBalance.parse(%{"wart" => %{"total" => %{"str" => "1.0"}}}) == :error
    end
  end

  describe "TokenBalance" do
    test "parses the token and the three amounts" do
      data = %{
        "token" => %{"name" => "TOK2", "decimals" => 4},
        "balance" => %{
          "total" => %{"str" => "1000.0000", "u64" => 10_000_000, "decimals" => 4},
          "locked" => %{"str" => "100.0000", "u64" => 1_000_000, "decimals" => 4},
          "mempool" => %{"str" => "0.0000", "u64" => 0, "decimals" => 4}
        }
      }

      assert {:ok, balance} = TokenBalance.parse(data)
      assert balance.name == "TOK2"
      assert balance.decimals.decimals == 4
      assert balance.total.amount == 10_000_000
      assert balance.locked.amount == 1_000_000
      assert balance.mempool.amount == 0
    end

    test "free is the total minus the two locked parts" do
      data = %{
        "token" => %{"name" => "TOK2", "decimals" => 4},
        "balance" => %{
          "total" => %{"str" => "1000.0000", "decimals" => 4},
          "locked" => %{"str" => "100.0000", "decimals" => 4},
          "mempool" => %{"str" => "50.0000", "decimals" => 4}
        }
      }

      assert {:ok, balance} = TokenBalance.parse(data)
      assert {:ok, free} = TokenBalance.free(balance)
      assert free.amount == 8_500_000
    end

    test "a balance that does not add up is rejected" do
      data = %{
        "token" => %{"name" => "TOK2", "decimals" => 4},
        "balance" => %{
          "total" => %{"str" => "1.0000", "decimals" => 4},
          "locked" => %{"str" => "2.0000", "decimals" => 4},
          "mempool" => %{"str" => "0.0000", "decimals" => 4}
        }
      }

      assert TokenBalance.parse(data) == :error
    end

    test "a malformed payload is rejected" do
      assert TokenBalance.parse(%{}) == :error
      assert TokenBalance.parse(%{"token" => %{"name" => "TOK2"}}) == :error
    end
  end
end
