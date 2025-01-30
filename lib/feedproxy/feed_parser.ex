defmodule Feedproxy.FeedParser do
  import SweetXml
  alias Feedproxy.FeedItem
  alias Feedproxy.Subscription

  def parse(content, subscription) do
    case subscription.feed_type do
      "rss" -> parse_rss(content, subscription)
      _ -> []
    end
  end

  defp parse_rss(content, subscription) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    cutoff_date = subscription.last_synced_at

    content
    |> xpath(~x"//item"l,
      title: ~x"./title/text()"s,
      url: ~x"./link/text()"s,
      excerpt: ~x"./description/text()"s,
      published_at: ~x"./pubDate/text()"s |> transform_by(&parse_date/1),
      subscription_id: ~x"." |> transform_by(fn _ -> subscription.id end)
    )
    |> Enum.filter(fn item ->
      DateTime.compare(item.published_at, cutoff_date) == :gt
    end)
    |> Enum.map(fn item ->
      Map.merge(item, %{
        inserted_at: now,
        updated_at: now
      })
    end)
  end

  defp parse_date(date_string) do
    # Try parsing RFC822 format (common in RSS)
    case Timex.parse(date_string, "{RFC822}") do
      {:ok, datetime} -> DateTime.from_naive!(datetime, "Etc/UTC")
      {:error, _} ->
        # If parsing fails, try ISO8601
        case DateTime.from_iso8601(date_string) do
          {:ok, datetime, _offset} -> datetime
          {:error, _} -> DateTime.utc_now()
        end
    end
  end
end
