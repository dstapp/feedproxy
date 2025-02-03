defmodule Feedproxy.FeedParser do
  import SweetXml
  alias Feedproxy.FeedItem
  alias Feedproxy.Subscription

  def parse(content, subscription) do
    # Determine feed type from content instead of relying on subscription.feed_type
    feed_type = detect_feed_type(content)


    case feed_type do
      "rss" -> parse_rss(content, subscription)
      "atom" -> parse_atom(content, subscription)
      _ -> []
    end
  end

  defp detect_feed_type(content) do
    try do
      cond do
        # Check for RSS 2.0 with version attribute (most common case)
        content |> xpath(~x"//rss[@version='2.0']") ->
          IO.puts("Detected RSS 2.0 via version attribute")
          "rss"

        # Check for RSS with content namespace
        content |> xpath(~x"//rss[contains(@xmlns:content, 'http://purl.org/rss/1.0/modules/content/')]") ->
          IO.puts("Detected RSS via content namespace")
          "rss"

        # Check for RSS with any common namespace
        content |> xpath(~x"//rss[contains(@xmlns:wfw, 'http://wellformedweb.org/CommentAPI/') or contains(@xmlns:itunes, 'http://www.itunes.com/dtds/podcast-1.0.dtd') or contains(@xmlns:dc, 'http://purl.org/dc/elements/1.1/')]") ->
          IO.puts("Detected RSS via common namespaces")
          "rss"

        # Check for RSS 1.0
        content |> xpath(~x"//rdf:RDF[contains(@xmlns,'http://purl.org/rss/1.0/')]") ->
          IO.puts("Detected RSS 1.0")
          "rss"

        # Check for Atom
        content |> xpath(~x"//feed") ->
          IO.puts("Detected Atom")
          "atom"

        # Default to RSS if we find any RSS-like elements
        content |> xpath(~x"//rss") ->
          IO.puts("Detected RSS (generic)")
          "rss"

        true ->
          IO.puts("Could not detect feed type")
          nil
      end
    rescue
      error ->
        IO.puts("Error detecting feed type: #{inspect(error)}")
        nil
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
      case cutoff_date do
        nil -> true
        _ -> DateTime.compare(item.published_at, cutoff_date) == :gt
      end
    end)
    |> Enum.map(fn item ->
      Map.merge(item, %{
        inserted_at: now,
        updated_at: now
      })
    end)
  end

  defp parse_date(date_string) do
    case :httpd_util.convert_request_date(String.to_charlist(date_string)) do
      {{year, month, day}, {hour, minute, second}} ->
        %DateTime{
          year: year,
          month: month,
          day: day,
          hour: hour,
          minute: minute,
          second: second,
          microsecond: {0, 0},
          time_zone: "Etc/UTC",
          zone_abbr: "UTC",
          utc_offset: 0,
          std_offset: 0
        }
      _ ->
        IO.puts("Failed to parse date: #{date_string}")
        DateTime.utc_now()
    end
  end

  defp parse_atom(content, subscription) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    cutoff_date = subscription.last_synced_at

    content
    |> xpath(~x"//entry"l,
      title: ~x"./title/text()"s,
      url: ~x"./link[@rel='alternate']/@href"s |> transform_by(&String.trim/1),
      excerpt: ~x"./summary/text()|./content/text()"s,
      published_at: ~x"./published/text()"s |> transform_by(&parse_atom_date/1),
      subscription_id: ~x"." |> transform_by(fn _ -> subscription.id end)
    )
    |> Enum.filter(fn item ->
      case cutoff_date do
        nil -> true
        _ -> DateTime.compare(item.published_at, cutoff_date) == :gt
      end
    end)
    |> Enum.map(fn item ->
      Map.merge(item, %{
        inserted_at: now,
        updated_at: now
      })
    end)
  end

  defp parse_atom_date(date_string) do
    case DateTime.from_iso8601(date_string) do
      {:ok, datetime, _offset} ->
        datetime
      _ ->
        IO.puts("Failed to parse atom date: #{date_string}")
        DateTime.utc_now()
    end
  end
end
