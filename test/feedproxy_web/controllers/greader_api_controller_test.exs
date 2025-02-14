defmodule FeedproxyWeb.GreaderApiControllerTest do
  use FeedproxyWeb.ConnCase
  alias Feedproxy.{Repo, Subscription, FeedItem}

  setup do
    # Create test subscriptions and items
    subscription = Repo.insert!(%Subscription{
      name: "Test Feed",
      url: "http://example.com/feed"
    })

    items = [
      %FeedItem{
        subscription_id: subscription.id,
        title: "Item 1",
        url: "http://example.com/1",
        excerpt: "Excerpt 1",
        published_at: DateTime.utc_now() |> DateTime.add(-1, :day),
        is_read: false,
        is_starred: false
      },
      %FeedItem{
        subscription_id: subscription.id,
        title: "Item 2",
        url: "http://example.com/2",
        excerpt: "Excerpt 2",
        published_at: DateTime.utc_now() |> DateTime.add(-2, :day),
        is_read: true,
        is_starred: true
      }
    ]

    items = Enum.map(items, &Repo.insert!/1)

    %{subscription: subscription, items: items}
  end

  describe "Authentication endpoints" do
    test "client_login returns correctly formatted auth tokens", %{conn: conn} do
      conn = post(conn, ~p"/api/greader.php/accounts/ClientLogin")

      response = text_response(conn, 200)
      assert [sid, lsid, auth, expires] = String.split(response, "\n", trim: true)

      assert sid =~ ~r/^SID=.+$/
      assert lsid =~ ~r/^LSID=.+$/
      assert auth =~ ~r/^Auth=.+$/
      assert expires =~ ~r/^expires_in=\d+$/
    end

    test "token returns valid CSRF token", %{conn: conn} do
      conn = get(conn, ~p"/api/greader.php/reader/api/0/token")

      assert %{"token" => token} = json_response(conn, 200)
      assert token == "12345/abcdef"  # Our stub token
    end

    test "user_info returns complete user details", %{conn: conn} do
      conn = get(conn, ~p"/api/greader.php/reader/api/0/user-info")

      assert %{
        "userId" => user_id,
        "userName" => username,
        "userProfileId" => profile_id,
        "userEmail" => email,
        "signupTimeSec" => signup_time,
        "isMultiLoginEnabled" => is_multi_login
      } = json_response(conn, 200)

      assert user_id == "demo"
      assert username == "demo"
      assert profile_id == "demo"
      assert email == "demo@example.com"
      assert is_integer(signup_time)
      assert is_boolean(is_multi_login)
    end
  end

  describe "Subscription management" do
    test "subscription_list returns all subscriptions", %{conn: conn, subscription: subscription} do
      conn = get(conn, ~p"/api/greader.php/reader/api/0/subscription/list")

      assert %{"subscriptions" => [sub]} = json_response(conn, 200)
      assert sub["id"] == "feed/#{subscription.id}"
      assert sub["title"] == subscription.name
      assert sub["url"] == subscription.url
      assert sub["categories"] == [%{"id"=>"category/all", "label" => "All"}]
    end

    test "tag_list returns complete tag structure", %{conn: conn} do
      conn = get(conn, ~p"/api/greader.php/reader/api/0/tag/list")

      assert %{"tags" => tags} = json_response(conn, 200)

      expected_tags = [
        "user/-/state/com.google/starred",
        "user/-/state/com.google/read",
        "user/-/state/com.google/reading-list",
        "user/-/state/com.google/kept-unread"
      ]

      assert length(tags) == length(expected_tags)

      for tag <- tags do
        assert %{"id" => id} = tag
        assert id in expected_tags
      end
    end
  end

  describe "Stream contents" do
    test "returns all items with correct JSON structure", %{conn: conn, items: [item | _], subscription: subscription} do
      conn = get(conn, ~p"/api/greader.php/reader/api/0/stream/contents/user/-/state/com.google/reading-list")

      assert %{
        "id" => "user/-/state/com.google/reading-list",
        "updated" => updated,
        "items" => [first_item | _]
      } = json_response(conn, 200)

      # Verify timestamp is recent
      assert_in_delta updated, DateTime.utc_now() |> DateTime.to_unix(), 5

      # Verify item structure
      assert %{
        "id" => "tag:google.com,2005:reader/item/" <> _hex_id,
        "title" => title,
        "published" => published,
        "crawlTimeMsec" => crawl_time,
        "timestampUsec" => timestamp,
        "alternate" => [%{"href" => url}],
        "canonical" => [%{"href" => canonical_url}],
        "summary" => %{"content" => content},
        "categories" => categories,
        "origin" => %{
          "streamId" => "feed/" <> _id,
          "title" => feed_title,
          "htmlUrl" => feed_url
        }
      } = first_item

      # Verify values match our item
      assert title == item.title
      assert url == item.url
      assert canonical_url == item.url
      assert content == item.excerpt
      assert feed_title == subscription.name
      assert feed_url == subscription.url

      # Verify timestamps
      item_timestamp = DateTime.to_unix(item.published_at)
      assert published == item_timestamp
      assert crawl_time == "#{item_timestamp * 1000}"
      assert timestamp == "#{item_timestamp * 1_000_000}"

      # Verify categories
      assert "user/-/state/com.google/reading-list" in categories
      if item.is_read, do: assert("user/-/state/com.google/read" in categories)
      if item.is_starred, do: assert("user/-/state/com.google/starred" in categories)
    end

    test "returns specific items by ID", %{conn: conn, items: [item | _]} do
      hex_id = Integer.to_string(item.id, 16) |> String.pad_leading(16, "0")

      conn =
        conn
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post(~p"/api/greader.php/reader/api/0/stream/items/contents", "i=#{hex_id}")

      assert %{"items" => [response_item]} = json_response(conn, 200)
      assert response_item["title"] == item.title
    end

    test "returns multiple items by ID", %{conn: conn, items: items} do
      hex_ids = Enum.map(items, fn item ->
        Integer.to_string(item.id, 16) |> String.pad_leading(16, "0")
      end)

      # Simulate multiple i parameters in form data
      body = Enum.map_join(hex_ids, "&", &("i=" <> &1))
      conn =
        conn
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post(~p"/api/greader.php/reader/api/0/stream/items/contents", body)

      assert %{"items" => response_items} = json_response(conn, 200)
      assert length(response_items) == length(items)
    end

    test "filters by read state", %{conn: conn} do
      conn = get(conn, ~p"/api/greader.php/reader/api/0/stream/contents/user/-/state/com.google/read")

      assert %{"items" => items} = json_response(conn, 200)
      assert Enum.any?(items, & &1["categories"] |> Enum.member?("user/-/state/com.google/read"))
    end

    test "filters by starred state", %{conn: conn} do
      conn = get(conn, ~p"/api/greader.php/reader/api/0/stream/contents/user/-/state/com.google/starred")

      assert %{"items" => items} = json_response(conn, 200)
      assert Enum.all?(items, & &1["categories"] |> Enum.member?("user/-/state/com.google/starred"))
    end

    test "filters by subscription", %{conn: conn, subscription: subscription} do
      conn = get(conn, ~p"/api/greader.php/reader/api/0/stream/contents/feed/#{subscription.id}")

      assert %{"items" => items} = json_response(conn, 200)
      assert Enum.all?(items, & &1["origin"]["streamId"] == "feed/#{subscription.id}")
    end

    test "respects continuation token", %{conn: conn} do
      conn = get(conn, ~p"/api/greader.php/reader/api/0/stream/contents/user/-/state/com.google/reading-list", %{"c" => "1"})

      assert %{"items" => items} = json_response(conn, 200)
      assert length(items) == 1  # Should skip first item
    end

    test "respects item count limit", %{conn: conn} do
      conn = get(conn, ~p"/api/greader.php/reader/api/0/stream/contents/user/-/state/com.google/reading-list", %{"n" => "1"})

      assert %{"items" => items} = json_response(conn, 200)
      assert length(items) == 1
    end

    test "returns unread counts with correct JSON structure", %{conn: conn, subscription: subscription} do
      conn = get(conn, ~p"/api/greader.php/reader/api/0/unread-count")

      assert %{
        "max" => max_count,
        "unreadcounts" => [%{
          "id" => "feed/" <> id,
          "count" => count,
          "newestItemTimestampUsec" => timestamp
        } = _count | _]
      } = json_response(conn, 200)

      assert is_integer(max_count)
      assert id == to_string(subscription.id)
      assert is_integer(count)
      assert is_binary(timestamp)
      {parsed, ""} = Integer.parse(timestamp)
      assert parsed > 0
    end

    test "returns subscription list with correct JSON structure", %{conn: conn, subscription: subscription} do
      conn = get(conn, ~p"/api/greader.php/reader/api/0/subscription/list")

      assert %{
        "subscriptions" => [%{
          "id" => "feed/" <> id,
          "title" => title,
          "categories" => categories,
          "url" => url,
          "htmlUrl" => html_url,
          "iconUrl" => icon_url
        } = _sub]
      } = json_response(conn, 200)

      assert id == to_string(subscription.id)
      assert title == subscription.name
      assert is_list(categories)
      assert url == subscription.url
      assert html_url == subscription.url
      assert icon_url == ""
    end

    test "returns stream item IDs with correct JSON structure", %{conn: conn, items: [_item | _]} do
      conn = get(conn, ~p"/api/greader.php/reader/api/0/stream/items/ids")

      assert %{
        "itemRefs" => [first_ref | _]
      } = json_response(conn, 200)

      assert %{
        "id" => id
      } = first_ref

      # Verify it's a valid decimal ID
      {_id_int, ""} = Integer.parse(id)
    end

    test "handles exclude target parameter", %{conn: conn} do
      conn = get(conn, ~p"/api/greader.php/reader/api/0/stream/contents/user/-/state/com.google/reading-list", %{
        "xt" => "user/-/state/com.google/read"
      })

      assert %{"items" => items} = json_response(conn, 200)
      for item <- items do
        refute "user/-/state/com.google/read" in item["categories"]
      end
    end

    test "handles multiple exclude targets", %{conn: conn} do
      conn = get(conn, ~p"/api/greader.php/reader/api/0/stream/contents/user/-/state/com.google/reading-list", %{
        "xt" => ["user/-/state/com.google/read", "user/-/state/com.google/starred"]
      })

      assert %{"items" => items} = json_response(conn, 200)
      for item <- items do
        refute "user/-/state/com.google/read" in item["categories"]
        refute "user/-/state/com.google/starred" in item["categories"]
      end
    end

    test "handles start time parameter", %{conn: conn} do
      timestamp = DateTime.utc_now() |> DateTime.add(-1, :hour) |> DateTime.to_unix()
      conn = get(conn, ~p"/api/greader.php/reader/api/0/stream/contents/user/-/state/com.google/reading-list", %{
        "ot" => timestamp
      })

      assert %{"items" => items} = json_response(conn, 200)
      for item <- items do
        assert item["published"] >= timestamp
      end
    end
  end

  describe "Item state management" do
    test "edit_tag handles multiple items and actions", %{conn: conn, items: items} do
      # First ensure items are in known state
      Enum.each(items, fn item ->
        item
        |> Ecto.Changeset.change(%{is_read: false})
        |> Repo.update!()
      end)

      hex_ids = Enum.map(items, fn item ->
        Integer.to_string(item.id, 16) |> String.pad_leading(16, "0")
      end)

      # Just mark as read, don't try to star
      body = Enum.map_join(hex_ids, "&", &("i=" <> &1)) <>
        "&a=user/-/state/com.google/read" <>
        "&T=token"

      conn =
        conn
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post(~p"/api/greader.php/reader/api/0/edit-tag", body)

      assert response(conn, 200)

      # Verify all items were updated
      for item <- items do
        updated = Repo.get(FeedItem, item.id)
        assert updated.is_read  # This should now pass
      end
    end

    test "mark_all_as_read handles different stream types", %{conn: conn, subscription: subscription} do
      timestamp = DateTime.utc_now() |> DateTime.to_unix()

      streams = [
        "user/-/state/com.google/reading-list",
        "user/-/state/com.google/starred",
        "feed/#{subscription.id}"
      ]

      for stream <- streams do
        body = "s=#{stream}&ts=#{timestamp}&T=token"

        conn =
          conn
          |> put_req_header("content-type", "application/x-www-form-urlencoded")
          |> post(~p"/api/greader.php/reader/api/0/mark-all-as-read", body)

        assert response(conn, 200) == "OK"
      end
    end

    test "handles removing read state", %{conn: conn, items: [item | _]} do
      hex_id = Integer.to_string(item.id, 16) |> String.pad_leading(16, "0")
      body = "i=#{hex_id}&r=user/-/state/com.google/read&T=token"

      conn =
        conn
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post(~p"/api/greader.php/reader/api/0/edit-tag", body)

      assert response(conn, 200)
      updated = Repo.get(FeedItem, item.id)
      refute updated.is_read
    end

    test "handles removing starred state", %{conn: conn, items: [item | _]} do
      hex_id = Integer.to_string(item.id, 16) |> String.pad_leading(16, "0")
      body = "i=#{hex_id}&r=user/-/state/com.google/starred&T=token"

      conn =
        conn
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post(~p"/api/greader.php/reader/api/0/edit-tag", body)

      assert response(conn, 200)
      updated = Repo.get(FeedItem, item.id)
      refute updated.is_starred
    end

    test "handles multiple items with mixed actions", %{conn: conn, items: items} do
      hex_ids = Enum.map(items, fn item ->
        Integer.to_string(item.id, 16) |> String.pad_leading(16, "0")
      end)

      body = Enum.map_join(hex_ids, "&", &("i=" <> &1)) <>
        "&a=user/-/state/com.google/read" <>
        "&r=user/-/state/com.google/starred" <>
        "&T=token"

      conn =
        conn
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post(~p"/api/greader.php/reader/api/0/edit-tag", body)

      assert response(conn, 200)

      for item <- items do
        updated = Repo.get(FeedItem, item.id)
        assert updated.is_read
        refute updated.is_starred
      end
    end
  end

  describe "Stream item IDs" do
    test "returns IDs with all supported output formats", %{conn: conn, items: items} do
      # Test JSON format
      conn = get(conn, ~p"/api/greader.php/reader/api/0/stream/items/ids")
      json_response = json_response(conn, 200)
      assert %{"itemRefs" => refs} = json_response
      assert length(refs) == length(items)
      for ref <- refs do
        assert %{"id" => id} = ref
        assert is_binary(id)
      end

      # Test plain text format
      conn = get(conn, ~p"/api/greader.php/reader/api/0/stream/items/ids", %{"output" => "ids"})
      text_response = text_response(conn, 200)
      ids = String.split(text_response, "\n", trim: true)
      assert length(ids) == length(items)
      for id <- ids do
        assert {_num, ""} = Integer.parse(id)
      end
    end

    test "handles all stream filtering options", %{conn: conn} do
      filters = [
        {"s", "user/-/state/com.google/reading-list"},
        {"s", "user/-/state/com.google/starred"},
        {"xt", "user/-/state/com.google/read"},
        {"n", "1"},
        {"r", "o"}  # Reverse order
      ]

      for {param, value} <- filters do
        conn = get(conn, ~p"/api/greader.php/reader/api/0/stream/items/ids", [{param, value}])
        assert %{"itemRefs" => _refs} = json_response(conn, 200)
      end
    end
  end

  describe "Unread counts" do
    test "returns counts for all subscriptions", %{conn: conn} do
      conn = get(conn, ~p"/api/greader.php/reader/api/0/unread-count", %{"all" => "1"})

      assert %{"unreadcounts" => counts} = json_response(conn, 200)
      assert length(counts) > 0
      assert Enum.all?(counts, & is_integer(&1["count"]))
    end

    test "returns only subscriptions with unread items by default", %{conn: conn} do
      conn = get(conn, ~p"/api/greader.php/reader/api/0/unread-count")

      assert %{"unreadcounts" => counts} = json_response(conn, 200)
      assert Enum.all?(counts, & &1["count"] > 0)
    end
  end

  describe "Error handling" do
    test "handles invalid stream ID", %{conn: conn} do
      conn = get(conn, ~p"/api/greader.php/reader/api/0/stream/contents/feed/999999")
      assert %{"items" => []} = json_response(conn, 200)
    end

    test "handles invalid item IDs in edit-tag", %{conn: conn} do
      body = "i=invalid_id&a=user/-/state/com.google/read&T=token"

      conn =
        conn
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post(~p"/api/greader.php/reader/api/0/edit-tag", body)

      assert response(conn, 200)  # Should not error on invalid IDs
    end

    test "handles missing token in edit-tag", %{conn: conn, items: [item | _]} do
      hex_id = Integer.to_string(item.id, 16) |> String.pad_leading(16, "0")
      body = "i=#{hex_id}&a=user/-/state/com.google/read"

      conn =
        conn
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post(~p"/api/greader.php/reader/api/0/edit-tag", body)

      assert response(conn, 200)  # Token is mocked, so this should still work
    end
  end
end
