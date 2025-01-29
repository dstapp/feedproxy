defmodule FeedproxyWeb.Api.FeedItemJSON do
  alias Feedproxy.FeedItem
  alias Feedproxy.Subscription

  def index(%{feed_items: feed_items}) do
    %{data: for(feed_item <- feed_items, do: data(feed_item))}
  end

  defp data(%FeedItem{} = feed_item) do
    %{
      id: feed_item.id,
      title: feed_item.title,
      url: feed_item.url,
      published_at: feed_item.published_at,
      excerpt: feed_item.excerpt,
      is_read: feed_item.is_read,
      is_starred: feed_item.is_starred,
      subscription_id: feed_item.subscription_id
    }
  end
end
