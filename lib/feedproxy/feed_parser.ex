defmodule Feedproxy.FeedParser do
  import SweetXml

  def parse(content, subscription) do
    case subscription.feed_type do
      "rss" -> parse_rss(content, subscription)
      _ -> []
    end
  end

  defp parse_rss(content, subscription) do
    content
    |> xpath(~x"//item"l,
      title: ~x"./title/text()"s,
      url: ~x"./link/text()"s,
      content: ~x"./description/text()"s,
      published_at: ~x"./pubDate/text()"s |> transform_by(&parse_date/1),
      subscription_id: ~x"." |> transform_by(fn _ -> subscription.id end)
    )
  end

  defp parse_date(date_string) do
    case NaiveDateTime.from_iso8601(date_string) do
      {:ok, datetime} -> datetime
      _ -> NaiveDateTime.utc_now()
    end
  end

  defp parse_content(content) when is_binary(content), do: content
  defp parse_content(_), do: ""
end
