defmodule FeedproxyWeb.Api.FeedItemController do
  use FeedproxyWeb, :controller

  alias Feedproxy.{FeedItem, Repo, FeedSyncer}

  action_fallback FeedproxyWeb.FallbackController

  def index(conn, _params) do
    feed_items = Repo.all(FeedItem)
    render(conn, :index, feed_items: feed_items)
  end

  def sync(conn, _params) do
    FeedSyncer.sync_now()
    render(conn, :index, feed_items: [])
  end
end
