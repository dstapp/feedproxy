defmodule Feedproxy.FeedParser do
  import SweetXml
  require Logger

  def parse(content, subscription) do
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
          "rss"

        # Check for RSS with content namespace
        content |> xpath(~x"//rss[contains(@xmlns:content, 'http://purl.org/rss/1.0/modules/content/')]") ->
          "rss"

        # Check for RSS with any common namespace
        content |> xpath(~x"//rss[contains(@xmlns:wfw, 'http://wellformedweb.org/CommentAPI/') or contains(@xmlns:itunes, 'http://www.itunes.com/dtds/podcast-1.0.dtd') or contains(@xmlns:dc, 'http://purl.org/dc/elements/1.1/')]") ->
          "rss"

        # Check for RSS 1.0
        content |> xpath(~x"//rdf:RDF[contains(@xmlns,'http://purl.org/rss/1.0/')]") ->
          "rss"

        # Check for Atom
        content |> xpath(~x"//feed") ->
          "atom"

        # Default to RSS if we find any RSS-like elements
        content |> xpath(~x"//rss") ->
          "rss"

        true ->
          Logger.warning("Could not detect feed type")
          nil
      end
    rescue
      error ->
        Logger.error("Error detecting feed type: #{inspect(error)}")
        nil
    end
  end

  defp parse_rss(content, subscription) do
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
  end

  def parse_date(date_string) do
    iana_timezones = %{
      "PST" => "-0800", "PDT" => "-0700",  # Pacific Time
      "MST" => "-0700", "MDT" => "-0600",  # Mountain Time
      "CST" => "-0600", "CDT" => "-0500",  # Central Time
      "EST" => "-0500", "EDT" => "-0400"   # Eastern Time
    }

    # Replace US time zones with their UTC offset
    date_string =
      Enum.reduce(iana_timezones, date_string, fn {tz, offset}, acc ->
        String.replace(acc, tz, offset)
      end)

    case Timex.parse(date_string, "{RFC1123}") do
      {:ok, datetime} -> Timex.to_datetime(datetime, "UTC")
      {:error, _} -> DateTime.utc_now()
    end
  end

  defp parse_atom(content, subscription) do
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
  end

  def parse_atom_date(date_string) do
    case Timex.parse(date_string, "{ISO:Extended}") do
      {:ok, datetime} -> Timex.to_datetime(datetime, "UTC")
      {:error, _} -> DateTime.utc_now()
    end
  end
end
