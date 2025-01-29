defmodule FeedproxyWeb.Api.FeedItemControllerTest do
  use FeedproxyWeb.ConnCase

  # Optional: Import factory functions if using ex_machina
  # import Feedproxy.Factory

  # Setup block to create test data
  setup %{conn: conn} do
    # Create test data
    valid_attrs = %{}

    {:ok, conn: put_req_header(conn, "accept", "application/json"), valid_attrs: valid_attrs}
  end

  describe "index" do
    setup [:create_feed_item]

    test "lists all feed items", %{conn: conn} do
      conn = get(conn, ~p"/api/feed-items")

      assert [
               %{
                 "id" => _id,
                 "url" => _url,
                 "excerpt" => _excerpt,
                 "title" => _title,
                 "subscription_id" => _subscription_id,
                 "published_at" => _published_at,
                 "is_starred" => _is_starred,
                 "is_read" => _is_read
               }
             ] = json_response(conn, 200)["data"]
    end
  end

  #
  # Helper function to create a subscription for tests
  defp create_feed_item(_) do
    {:ok, feed_item} =
      Feedproxy.Repo.insert(%Feedproxy.FeedItem{
        url: "https://example.com/article",
        title: "Example article"
      })

    %{feed_item: feed_item}
  end
end
