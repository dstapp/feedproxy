defmodule FeedproxyWeb.GreaderApiController do
  use FeedproxyWeb, :controller
  import Ecto.Query
  alias Feedproxy.{FeedItem, Subscription, Repo}

  # Stub auth token - in production this should be properly implemented
  @stub_auth_token "12345/abcdef"
  @stub_user "demo"

  # Authentication endpoints
  def client_login(conn, _params) do
    # FreshRSS accepts both form data and JSON
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "SID=#{@stub_auth_token}\nLSID=#{@stub_auth_token}\nAuth=#{@stub_auth_token}\nexpires_in=604800")
  end

  def token(conn, _params) do
    json(conn, %{"token" => @stub_auth_token})
  end

  # User info endpoint
  def user_info(conn, _params) do
    json(conn, %{
      "userId" => @stub_user,
      "userName" => @stub_user,
      "userProfileId" => @stub_user,
      "userEmail" => "#{@stub_user}@example.com",
      "signupTimeSec" => 1_000_000_000,
      "isMultiLoginEnabled" => false
    })
  end

  # Subscription management
  def subscription_list(conn, _params) do
    subscriptions = Subscription
    |> Repo.all()
    |> Enum.map(fn subscription ->
      %{
        "id" => "feed/#{subscription.id}",
        "title" => subscription.name,
        "categories" => [%{"id"=>"category/all", "label" => "All"}],
        "url" => subscription.url,
        "htmlUrl" => subscription.url,
        "iconUrl" => ""
      }
    end)

    json(conn, %{
      "subscriptions" => subscriptions
    })
  end

  def tag_list(conn, _params) do
    json(conn, %{
      "tags" => [
        %{"id" => "user/-/state/com.google/starred"},
        %{"id" => "user/-/state/com.google/read"},
        %{"id" => "user/-/state/com.google/reading-list"},
        %{"id" => "user/-/state/com.google/kept-unread"}
      ]
    })
  end

  # Stream contents should return full items
  def stream_contents(conn, params) do
    {query, stream_id} = cond do
      # Handle item ID list case
      params["i"] != nil ->
        item_ids = parse_item_ids_from_body(conn) # important: apps like Reeder send multiple i parameters, so we need to parse them all, also in other endpoints
        {FeedItem |> where([i], i.id in ^item_ids), "user/-/state/com.google/reading-list"}

      # Handle normal stream case
      true ->
        stream_id = case params["streamId"] do
          nil -> "user/-/state/com.google/reading-list"
          [] -> "user/-/state/com.google/reading-list"
          "" -> "user/-/state/com.google/reading-list"
          streamId when is_list(streamId) -> Enum.join(streamId, "/")
          streamId -> streamId
        end

        query = case stream_id do
          "user/-/state/com.google/reading-list" ->
            FeedItem

          "user/-/state/com.google/starred" ->
            FeedItem
            |> where([i], i.is_starred == true)

          "user/-/state/com.google/read" ->
            FeedItem # contrary to expectation, this should return every single item (read or unread), see https://www.reddit.com/r/rss/comments/1dydx0x/implementing_the_google_reader_api_to_integrate

          "user/-/state/com.google/kept-unread" ->
            FeedItem
            |> where([i], i.is_read == false)

          "feed/" <> feed_id ->
            FeedItem
            |> where([i], i.subscription_id == ^feed_id)
        end

        {query, stream_id}
    end

    # Handle exclude targets (xt parameter)
    exclude_targets = List.wrap(params["xt"])
    query = Enum.reduce(exclude_targets, query, fn target, query ->
      case target do
        "user/-/state/com.google/read" ->
          query |> where([i], i.is_read == false)
        "user/-/state/com.google/starred" ->
          query |> where([i], i.is_starred == false)
        _ -> query
      end
    end)

    count = String.to_integer(params["n"] || "20")
    start_time = params["ot"] && String.to_integer(params["ot"])
    offset = case params["c"] do
      nil -> 0
      continuation -> String.to_integer(continuation)
    end

    query = if start_time do
      query |> where([i], i.published_at >= ^DateTime.from_unix!(start_time))
    else
      query
    end

    items = query
    |> limit(^count)
    |> offset(^offset)
    |> order_by([i], desc: i.published_at)
    |> Repo.all()
    |> Enum.map(fn item ->
      subscription = Repo.get(Subscription, item.subscription_id)
      timestamp = DateTime.to_unix(item.published_at)

      %{
        "id" => to_long_form_id(item.id),
        "title" => item.title,
        "published" => timestamp,
        "crawlTimeMsec" => "#{timestamp * 1000}",
        "timestampUsec" => "#{timestamp * 1_000_000}",
        "alternate" => [%{
          "href" => item.url,
        }],
        "canonical" => [%{
          "href" => item.url,
        }],
        "summary" => %{
          "content" => item.excerpt || ""
        },
        "categories" => item_categories(item),
        "origin" => %{
          "streamId" => "feed/#{item.subscription_id}",
          "title" => subscription.name,
          "htmlUrl" => subscription.url
        }
      }
    end)

    response = %{
      "id" => stream_id,
      "updated" => DateTime.utc_now() |> DateTime.to_unix(),
      "items" => items
    }

    # Only add continuation if we have a full page of results
    response = if length(items) == count do
      Map.put(response, "continuation", "#{offset + count}")
    else
      response
    end

    json(conn, response)
  end

  # Mark items as read/unread/starred
  def edit_tag(conn, params) do
    item_ids = parse_item_ids_from_body(conn)
    add_tags = List.wrap(params["a"])
    remove_tags = List.wrap(params["r"])

    items = FeedItem
    |> where([i], i.id in ^item_ids)
    |> Repo.all()

    Enum.each(items, fn item ->
      changes = %{}

      changes = Enum.reduce(add_tags, changes, fn tag, acc ->
        case tag do
          "user/-/state/com.google/read" -> Map.put(acc, :is_read, true)
          "user/-/state/com.google/starred" -> Map.put(acc, :is_starred, true)
          _ -> acc
        end
      end)

      changes = Enum.reduce(remove_tags, changes, fn tag, acc ->
        case tag do
          "user/-/state/com.google/read" -> Map.put(acc, :is_read, false)
          "user/-/state/com.google/starred" -> Map.put(acc, :is_starred, false)
          _ -> acc
        end
      end)

      if map_size(changes) > 0 do
        item
        |> Ecto.Changeset.change(changes)
        |> Repo.update()
      end
    end)

    conn
    |> put_resp_content_type("text/javascript; charset=UTF-8")
    |> send_resp(200, "OK")
  end

  # Mark all items as read
  def mark_all_as_read(conn, %{"s" => stream_id, "ts" => timestamp, "T" => _token}) do
    query = case stream_id do
      "user/-/state/com.google/reading-list" ->
        FeedItem

      "user/-/state/com.google/starred" ->
        FeedItem
        |> where([i], i.is_starred == true)

      "user/-/state/com.google/kept-unread" ->
        FeedItem
        |> where([i], i.is_read == false)

      "feed/" <> feed_id ->
        FeedItem
        |> where([i], i.subscription_id == ^feed_id)
    end

    query
    |> where([i], i.published_at <= ^DateTime.from_unix!(String.to_integer(timestamp), :microsecond))
    |> Repo.update_all(set: [is_read: true])

    conn
    |> put_resp_content_type("text/javascript; charset=UTF-8")
    |> send_resp(200, "OK")
  end

  # Unread counts
  def unread_count(conn, params) do
    # Get all feeds by default if all=1
    show_all = params["all"] == "1"

    counts = Subscription
    |> Repo.all()
    |> Enum.map(fn subscription ->
      unread_count = FeedItem
      |> where([i], i.subscription_id == ^subscription.id)
      |> where([i], i.is_read == false)
      |> Repo.aggregate(:count)

      newest_item = FeedItem
      |> where([i], i.subscription_id == ^subscription.id)
      |> order_by([i], desc: i.published_at)
      |> limit(1)
      |> Repo.one()

      # Only include feeds with unread items unless all=1
      if show_all or unread_count > 0 do
        %{
          "id" => "feed/#{subscription.id}",
          "count" => unread_count,
          "newestItemTimestampUsec" => if(newest_item) do
            "#{DateTime.to_unix(newest_item.published_at, :microsecond)}"
          else
            "0"
          end
        }
      end
    end)
    |> Enum.reject(&is_nil/1)  # Remove nil entries (feeds with no unread items when all=0)

    json(conn, %{
      "max" => Enum.sum(Enum.map(counts, & &1["count"])),
      "unreadcounts" => counts
    })
  end

  defp item_categories(item) do
    # Start with basic categories
    categories = [
      "user/-/state/com.google/reading-list"
    ]

    # Add read/unread state
    categories = if item.is_read do
      ["user/-/state/com.google/read" | categories]
    else
      categories
    end

    # Add starred state if applicable
    if item.is_starred do
      ["user/-/state/com.google/starred" | categories]
    else
      categories
    end
  end

  defp to_long_form_id(id) when is_integer(id) do
    hex = Integer.to_string(id, 16) |> String.pad_leading(16, "0")
    "tag:google.com,2005:reader/item/#{hex}"
  end

  defp to_short_form_id(id) when is_integer(id) do
    to_string(id)
  end

  def stream_item_ids(conn, params) do
    stream_id = params["s"] || "user/-/state/com.google/reading-list"
    count = String.to_integer(params["n"] || "10000")
    start_time = params["ot"] && String.to_integer(params["ot"])
    exclude_targets = List.wrap(params["xt"])
    include_targets = List.wrap(params["it"])
    reverse_sort = params["r"] == "o"
    output_format = params["output"] || "json"

    query = case stream_id do
      "user/-/state/com.google/reading-list" ->
        FeedItem

      "user/-/state/com.google/starred" ->
        FeedItem
        |> where([i], i.is_starred == true)

      "user/-/state/com.google/read" ->
        FeedItem # contrary to expectation, this should return every single item (read or unread), see https://www.reddit.com/r/rss/comments/1dydx0x/implementing_the_google_reader_api_to_integrate

      "user/-/state/com.google/kept-unread" ->
        FeedItem
        |> where([i], i.is_read == false)

      "feed/" <> feed_id ->
        FeedItem
        |> where([i], i.subscription_id == ^feed_id)
    end

    # Handle exclude targets
    query = Enum.reduce(exclude_targets, query, fn target, query ->
      case target do
        "user/-/state/com.google/read" ->
          query |> where([i], i.is_read == false)
        "user/-/state/com.google/starred" ->
          query |> where([i], i.is_starred == false)
        _ -> query
      end
    end)

    # Handle include targets
    query = Enum.reduce(include_targets, query, fn target, query ->
      case target do
        # "user/-/state/com.google/read" ->
        #   query |> where([i], i.is_read == true) # contrary to expectation, this should return every single item (read or unread), see https://www.reddit.com/r/rss/comments/1dydx0x/implementing_the_google_reader_api_to_integrate
        "user/-/state/com.google/starred" ->
          query |> where([i], i.is_starred == true)
        _ -> query
      end
    end)

    query = if start_time do
      query |> where([i], i.published_at >= ^DateTime.from_unix!(start_time))
    else
      query
    end

    # Handle sort order
    query = if reverse_sort do
      query |> order_by([i], asc: i.published_at)
    else
      query |> order_by([i], desc: i.published_at)
    end

    items = query
    |> limit(^count)
    |> Repo.all()
    |> Enum.map(fn item ->
      %{"id" => to_short_form_id(item.id)}
    end)

    case output_format do
      "ids" ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, Enum.map(items, & &1["id"]) |> Enum.join("\n"))

      _ ->
        json(conn, %{
          "itemRefs" => items
        })
    end
  end

  # Add this private function to handle ID parsing
  defp parse_reader_id(id) do
    case id do
      "tag:google.com,2005:reader/item/" <> hex_id ->
        # Handle long form ID (hex)
        case Integer.parse(hex_id, 16) do
          {int_id, _} -> {:ok, int_id}
          :error -> :error
        end
      hex_id when byte_size(hex_id) == 16 ->
        # Handle short form hex ID (16 chars, zero-padded)
        case Integer.parse(hex_id, 16) do
          {int_id, _} -> {:ok, int_id}
          :error -> :error
        end
      raw_id ->
        # Handle decimal ID
        case Integer.parse(raw_id) do
          {int_id, _} -> {:ok, int_id}
          :error -> :error
        end
    end
  end

  # Add this helper function to parse multiple i parameters from raw body
  defp parse_item_ids_from_body(conn) do
    conn.private[:raw_body]
    |> String.split("&")
    |> Enum.reduce([], fn param, acc ->
      case String.split(param, "=") do
        ["i", value] -> [URI.decode_www_form(value) | acc]
        _ -> acc
      end
    end)
    |> Enum.reduce([], fn id, acc ->
      case parse_reader_id(id) do
        {:ok, int_id} -> [int_id | acc]
        :error -> acc
      end
    end)
  end
end
