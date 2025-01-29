defmodule FeedproxyWeb.Api.FeedItemController do
  use FeedproxyWeb, :controller

  alias Feedproxy.FeedItem
  alias Feedproxy.Repo

  action_fallback FeedproxyWeb.FallbackController

  def index(conn, _params) do
    feed_items = Repo.all(FeedItem)
    render(conn, :index, feed_items: feed_items)
  end
end
