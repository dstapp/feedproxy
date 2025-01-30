defmodule FeedproxyWeb.Api.SubscriptionControllerTest do
  use FeedproxyWeb.ConnCase

  # Optional: Import factory functions if using ex_machina
  # import Feedproxy.Factory

  # Setup block to create test data
  setup %{conn: conn} do
    # Create test data
    valid_attrs = %{
      "url" => "https://example.com/feed",
      "name" => "Test Feed",
      "feed_type" => "rss"
    }

    {:ok, conn: put_req_header(conn, "accept", "application/json"), valid_attrs: valid_attrs}
  end

  describe "index" do
    setup [:create_subscription]

    test "lists all subscriptions", %{conn: conn} do
      conn = get(conn, ~p"/api/subscriptions")

      assert [
               %{
                 "id" => _id,
                 "url" => _url,
                 "name" => _name,
                 "feed_type" => _feed_type,
                 "last_synced_at" => _last_synced_at
               }
             ] = json_response(conn, 200)["data"]
    end
  end

  describe "create subscription" do
    test "renders subscription when data is valid", %{conn: conn, valid_attrs: valid_attrs} do
      conn = post(conn, ~p"/api/subscriptions", subscription: valid_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/subscriptions/#{id}")

      assert %{
               "id" => ^id,
               "url" => "https://example.com/feed",
               "name" => "Test Feed",
               "feed_type" => "rss"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/subscriptions", subscription: %{url: nil})
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update subscription" do
    setup [:create_subscription]

    test "renders subscription when data is valid", %{
      conn: conn,
      subscription: %{id: id} = subscription
    } do
      update_attrs = %{"name" => "Updated Name"}
      conn = put(conn, ~p"/api/subscriptions/#{subscription}", subscription: update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/subscriptions/#{id}")
      assert json_response(conn, 200)["data"]["name"] == "Updated Name"
    end
  end

  describe "delete subscription" do
    setup [:create_subscription]

    test "deletes chosen subscription", %{conn: conn, subscription: subscription} do
      conn = delete(conn, ~p"/api/subscriptions/#{subscription}")
      assert response(conn, 204)

      conn = get(conn, ~p"/api/subscriptions/#{subscription}")
      assert response(conn, 404)
    end
  end

  describe "import" do
    test "imports subscriptions from OPML file", %{conn: conn} do
      opml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="1.0">
        <head><title>Feed Subscriptions</title></head>
        <body>
          <outline title="Example Feed" type="rss" xmlUrl="https://example.com/feed.xml"/>
          <outline title="Another Feed" type="atom" xmlUrl="https://another.com/feed.atom"/>
        </body>
      </opml>
      """

      upload = %Plug.Upload{
        path: Path.expand("test/fixtures/feeds.opml"),
        filename: "feeds.opml"
      }

      # Write test file
      File.write!(upload.path, opml)

      conn = post(conn, ~p"/api/subscriptions/import", %{"file" => upload})

      assert json_response(conn, 201)["data"] |> length() == 2

      # Cleanup
      File.rm!(upload.path)
    end
  end

  # Helper function to create a subscription for tests
  defp create_subscription(_) do
    {:ok, subscription} =
      Feedproxy.Repo.insert(%Feedproxy.Subscription{
        url: "https://example.com/feed",
        name: "Test Feed",
        feed_type: "rss"
      })

    %{subscription: subscription}
  end
end
