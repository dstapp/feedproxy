defmodule Feedproxy.OpmlParser do
  import SweetXml

  def parse(content) do
    content
    |> xpath(~x"//outline"l,
      name: ~x"./@title"s,
      url: ~x"./@xmlUrl"s,
      feed_type: ~x"./@type"s |> transform_by(&normalize_feed_type/1)
    )
    |> Enum.filter(&valid_feed?/1)
  end

  defp normalize_feed_type("rss"), do: "rss"
  defp normalize_feed_type("atom"), do: "atom"
  defp normalize_feed_type(_), do: "rss" # default to RSS

  defp valid_feed?(%{url: url}) when is_binary(url) and url != "", do: true
  defp valid_feed?(_), do: false
end
