defprotocol WarthogEx.TransactionContext do
  @moduledoc """
  The transaction builder every context implements.

  The two node families accept different transaction sets, so the contexts are
  separate modules: `WarthogEx.LegacyTransactionContext` for the legacy node
  (core/master, core/dev) and `WarthogEx.DeFiTransactionContext` for the DeFi
  node (core/defi). A legacy context cannot build a limit swap, because that
  builder does not exist on it.

  This protocol carries the one builder both have, so calling code that only
  sends WART can hold either context and call it:

      WarthogEx.TransactionContext.transfer_wart(ctx, account, recipient, wart)
  """

  alias WarthogEx.Account
  alias WarthogEx.Address
  alias WarthogEx.Wart

  @type t :: struct()

  @spec transfer_wart(t(), Account.t(), Address.t(), Wart.t()) :: map()
  def transfer_wart(context, account, to_addr, wart)
end
