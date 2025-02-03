defmodule Feedproxy.FeedSyncer do
  use GenServer
  alias Feedproxy.{Subscription, FeedParser, Repo, FeedItem}
  require Logger

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    schedule_work()
    {:ok, state}
  end

  @impl true
  def handle_info(:work, state) do
    sync_subscriptions()
    schedule_work()
    {:noreply, state}
  end

  # Public API for manual syncing
  def sync_now do
    GenServer.cast(__MODULE__, :sync)
  end

  @impl true
  def handle_cast(:sync, state) do
    sync_subscriptions()
    {:noreply, state}
  end

  defp schedule_work do
    Process.send_after(self(), :work, 60_000)
  end

  def sync_subscriptions do
    sync_start_time = DateTime.utc_now() |> DateTime.truncate(:second)
    subscriptions = Repo.all(Subscription)

    tasks =
      subscriptions
      |> Enum.map(fn subscription ->
        Task.async(fn -> sync_subscription(subscription) end)
      end)

    results = Task.await_many(tasks, 30_000)

    # Filter successful results and flatten the list of items
    feed_items =
      results
      |> Enum.filter(fn result -> match?({:ok, _items}, result) end)
      |> Enum.flat_map(fn {:ok, items} -> items end)

    # Insert all items into the database using changesets
    feed_items
    |> Enum.map(fn item ->
      FeedItem.changeset(%FeedItem{}, item)
    end)
    |> Enum.each(fn changeset ->
      Repo.insert(changeset, on_conflict: :nothing)
    end)

    # Update last_synced_at for all successfully synced subscriptions
    results
    |> Enum.each(fn
      {:ok, []} ->
        # Successfully synced but no new items
        nil
      {:ok, items} ->
        subscription_id = List.first(items).subscription_id
        Repo.get(Subscription, subscription_id)
        |> Subscription.changeset(%{last_synced_at: sync_start_time})
        |> Repo.update()
      {:error, _} ->
        # Failed sync, skip updating last_synced_at
        nil
    end)
  end

  def sync_subscription(%Subscription{} = subscription) do
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
end
