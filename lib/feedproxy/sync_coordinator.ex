defmodule Feedproxy.SyncCoordinator do
  def sync_subscriptions do
    IO.puts("1. fetch all subscriptions")

    IO.puts(
      "2. spawn a process for each of the subscription that fetches the feed, gets items that are newer than last_synced_at, maps and returns them"
    )

    IO.puts("3. wait for all processes to finish and then write new feeditems to db")
    # @todo is it only about new feed items or also updates?
  end
end
