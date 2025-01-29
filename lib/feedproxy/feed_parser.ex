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

    content
    |> xpath(~x"//item"l,
      title: ~x"./title/text()"s,
      url: ~x"./link/text()"s,
      excerpt: ~x"./description/text()"s,
      published_at: ~x"./pubDate/text()"s |> transform_by(&parse_date/1),
      subscription_id: ~x"." |> transform_by(fn _ -> subscription.id end)
    )
    |> Enum.map(fn item ->
      Map.merge(item, %{
        inserted_at: now,
        updated_at: now
      })
    end)
  end

  defp parse_date(date_string) do
    case NaiveDateTime.from_iso8601(date_string) do
      # {:ok, datetime} -> datetime
      _ -> DateTime.utc_now()
    end
  end
end
