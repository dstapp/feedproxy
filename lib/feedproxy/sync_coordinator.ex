defmodule Feedproxy.SyncCoordinator do
  alias Feedproxy.Subscription
  alias Feedproxy.Repo
  alias Feedproxy.FeedItem
  alias Feedproxy.FeedParser

  def sync_subscriptions do
    sync_start_time = DateTime.utc_now() |> DateTime.truncate(:second)
    subscriptions = Repo.all(Subscription)

    tasks =
      subscriptions
      |> Enum.map(fn subscription ->
        Task.async(fn -> sync_subscription(subscription, sync_start_time) end)
      end)

    # reconsider 30 second timeout
    results = Task.await_many(tasks, 30_000)

    # Filter successful results and flatten the list of items
    feed_items =
      results
      |> Enum.filter(fn result -> match?({:ok, _items}, result) end)
      |> Enum.flat_map(fn {:ok, items} -> items end)

    IO.inspect(feed_items)

    # @todo get items that are newer than last_synced_at
    # @todo write new feeditems to db

    # Insert all items into the database
    Repo.insert_all(FeedItem, feed_items, on_conflict: :nothing)

    # Update last_synced_at using the sync_start_time
    results
    |> Enum.filter(fn
      {:ok, _items} -> true
      {:error, _} -> false
    end)
    |> Enum.each(fn {:ok, items} ->
      subscription_id = List.first(items).subscription_id
      Repo.get(Subscription, subscription_id)
      |> Ecto.Changeset.change(%{last_synced_at: sync_start_time})
      |> Repo.update()
    end)
  end

  def sync_subscription(%Subscription{} = subscription, sync_start_time) do
    IO.puts("Syncing subscription #{subscription.id}")

    case fetch_feed(subscription.url) do
      {:ok, feed_content} ->
        items = FeedParser.parse(feed_content, subscription)

        {:ok, items}

      {:error, reason} ->
        IO.puts("Failed to fetch feed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp fetch_feed(url) do
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "HTTP request failed with status code: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  # RSS dates look like: "Wed, 29 Jan 2025 13:35:00 +0100"
  defp parse_rss_date(date_string) do
    # First try RFC1123 format (most common in RSS)
    case NaiveDateTime.from_iso8601(date_string) do
      {:ok, datetime} ->
        datetime

      _ ->
        # If that fails, default to current time
        NaiveDateTime.utc_now()
    end
  end
end
