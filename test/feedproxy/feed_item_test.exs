defmodule Feedproxy.FeedItemTest do
  alias Feedproxy.FeedItem
  use Feedproxy.DataCase

  describe "feed item" do
    @valid_attrs %{
      title: "Example article",
      url: "https://example.com/article",
      published_at: ~U[2024-01-28 12:30:26Z],
      excerpt: "Test 123",
      is_read: false,
      is_starred: true,
      subscription_id: "123"
    }
    @invalid_attrs %{
      title: nil,
      url: nil,
      published_at: nil,
      excerpt: nil,
      is_read: nil,
      is_starred: nil,
      subscription_id: nil
    }

    test "changeset with valid attributes" do
      changeset = FeedItem.changeset(%FeedItem{}, @valid_attrs)
      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      changeset = FeedItem.changeset(%FeedItem{}, @invalid_attrs)
      refute changeset.valid?
    end

    test "changeset requires title" do
      attrs = Map.put(@valid_attrs, :title, "")
      changeset = FeedItem.changeset(%FeedItem{}, attrs)
      assert "can't be blank" in errors_on(changeset).title
    end

    test "changeset requires url" do
      attrs = Map.put(@valid_attrs, :url, "")
      changeset = FeedItem.changeset(%FeedItem{}, attrs)
      assert "can't be blank" in errors_on(changeset).url
    end

    test "changeset requires published_at" do
      attrs = Map.put(@valid_attrs, :published_at, nil)
      changeset = FeedItem.changeset(%FeedItem{}, attrs)
      assert "can't be blank" in errors_on(changeset).published_at
    end
  end
end
