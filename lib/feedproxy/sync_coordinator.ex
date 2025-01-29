defmodule Feedproxy.SyncCoordinator do
  alias Feedproxy.Subscription
  alias Feedproxy.Repo
  import SweetXml

  def sync_subscriptions do
    subscriptions = Repo.all(Subscription)

    subscriptions
    |> Enum.each(fn subscription ->
      spawn(__MODULE__, :sync_subscription, [subscription])
    end)
  end

  def sync_subscription(%Subscription{} = subscription) do
    IO.puts("Syncing subscription #{subscription.id}")

    case fetch_feed(subscription.url) do
      {:ok, feed_content} ->
        IO.inspect(feed_content)

        items = feed_content
        |> xpath(~x"//item"l,
          title: ~x"./title/text()"s,
          link: ~x"./link/text()"s,
          description: ~x"./description/text()"s,
          pub_date: ~x"./pubDate/text()"s
        )

        IO.inspect(items)

        {:ok, items}
        # @todo get items that are newer than last_synced_at
        # @todo write new feeditems to db

      {:error, reason} ->
        IO.puts("Failed to fetch feed: #{inspect(reason)}")
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
