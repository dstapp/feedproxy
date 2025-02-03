defmodule Feedproxy.FeedUpdaterTask do
  alias Feedproxy.SyncCoordinator
  use Task

  def start_link(args) do
    Task.start_link(__MODULE__, :run, [args])
  end

  def run(args) do
    receive do
    after 60_000 ->
      IO.puts("Syncing subscriptions")
      SyncCoordinator.sync_subscriptions()
      run(args)
    end
  end
end
