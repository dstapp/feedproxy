defmodule Feedproxy.FeedParserTest do
  use ExUnit.Case, async: true
  alias Feedproxy.FeedParser

  @rss_feed """
  <?xml version="1.0" encoding="UTF-8"?>
  <rss version="2.0">
    <channel>
      <title>Test Feed</title>
      <link>http://example.com</link>
      <description>Test Description</description>
      <item>
        <title>Test Item 1</title>
        <link>http://example.com/1</link>
        <description>Description 1</description>
        <pubDate>Tue, 21 Jan 2024 08:38:02 +0000</pubDate>
      </item>
      <item>
        <title>Test Item 2</title>
        <link>http://example.com/2</link>
        <description>Description 2</description>
        <pubDate>Mon, 20 Jan 2024 10:30:00 +0000</pubDate>
      </item>
    </channel>
  </rss>
  """

  @atom_feed """
  <?xml version="1.0" encoding="UTF-8"?>
  <feed xmlns="http://www.w3.org/2005/Atom">
    <title>Test Atom Feed</title>
    <link href="http://example.com"/>
    <entry>
      <title>Atom Item 1</title>
      <link rel="alternate" href="http://example.com/atom1"/>
      <summary>Atom Description 1</summary>
      <published>2024-01-21T08:38:02Z</published>
    </entry>
    <entry>
      <title>Atom Item 2</title>
      <link rel="alternate" href="http://example.com/atom2"/>
      <content>Atom Description 2</content>
      <published>2024-01-20T10:30:00Z</published>
    </entry>
  </feed>
  """

  @invalid_feed """
  <?xml version="1.0" encoding="UTF-8"?>
  <invalid>
    <not-a-feed>This is not a valid feed</not-a-feed>
  </invalid>
  """

  describe "parse/2" do
    test "parses RSS feed correctly" do
      subscription = %{id: 1, last_synced_at: nil}
      items = FeedParser.parse(@rss_feed, subscription)

      assert length(items) == 2
      [item1, item2] = items

      assert item1.title == "Test Item 1"
      assert item1.url == "http://example.com/1"
      assert item1.excerpt == "Description 1"
      assert item1.subscription_id == 1
      assert %DateTime{} = item1.published_at

      assert item2.title == "Test Item 2"
      assert item2.url == "http://example.com/2"
      assert item2.excerpt == "Description 2"
      assert item2.subscription_id == 1
      assert %DateTime{} = item2.published_at
    end

    test "parses Atom feed correctly" do
      subscription = %{id: 1, last_synced_at: nil}
      items = FeedParser.parse(@atom_feed, subscription)

      assert length(items) == 2
      [item1, item2] = items

      assert item1.title == "Atom Item 1"
      assert item1.url == "http://example.com/atom1"
      assert item1.excerpt == "Atom Description 1"
      assert item1.subscription_id == 1
      assert %DateTime{} = item1.published_at

      assert item2.title == "Atom Item 2"
      assert item2.url == "http://example.com/atom2"
      assert item2.excerpt == "Atom Description 2"
      assert item2.subscription_id == 1
      assert %DateTime{} = item2.published_at
    end

    test "filters items based on last_synced_at" do
      {:ok, cutoff_date, _} = DateTime.from_iso8601("2024-01-21T00:00:00Z")
      subscription = %{id: 1, last_synced_at: cutoff_date}

      items = FeedParser.parse(@rss_feed, subscription)
      assert length(items) == 1
      [item] = items
      assert item.title == "Test Item 1"
    end

    test "returns empty list for invalid feed" do
      subscription = %{id: 1, last_synced_at: nil}
      items = FeedParser.parse(@invalid_feed, subscription)
      assert items == []
    end

    test "handles RSS feed with missing fields" do
      feed = """
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <item>
            <title>Test Item</title>
            <link>http://example.com/1</link>
            <pubDate>Tue, 21 Jan 2024 08:38:02 +0000</pubDate>
          </item>
        </channel>
      </rss>
      """

      subscription = %{id: 1, last_synced_at: nil}
      [item] = FeedParser.parse(feed, subscription)
      assert item.title == "Test Item"
      assert item.url == "http://example.com/1"
    end

    test "handles Atom feed with missing fields" do
      feed = """
      <?xml version="1.0" encoding="UTF-8"?>
      <feed xmlns="http://www.w3.org/2005/Atom">
        <entry>
          <title>Test Item</title>
          <link rel="alternate" href="http://example.com/1"/>
        </entry>
      </feed>
      """

      subscription = %{id: 1, last_synced_at: nil}
      [item] = FeedParser.parse(feed, subscription)

      assert item.title == "Test Item"
      assert item.url == "http://example.com/1"
      assert item.excerpt == ""  # Default for missing summary/content
      assert %DateTime{} = item.published_at  # Should default to current time
    end

    test "handles malformed XML" do
      subscription = %{id: 1, last_synced_at: nil}
      assert FeedParser.parse(@invalid_feed, subscription) == []
    end
  end

  describe "detect_feed_type/1" do
    test "detects RSS 2.0" do
      feed = """
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel></channel>
      </rss>
      """
      assert FeedParser.parse(feed, %{id: 1, last_synced_at: nil}) == []
    end

    test "detects Atom" do
      feed = """
      <?xml version="1.0"?>
      <feed xmlns="http://www.w3.org/2005/Atom">
      </feed>
      """
      assert FeedParser.parse(feed, %{id: 1, last_synced_at: nil}) == []
    end

    test "handles malformed XML" do
      assert FeedParser.parse(@invalid_feed, %{id: 1, last_synced_at: nil}) == []
    end
  end
end
