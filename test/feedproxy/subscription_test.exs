defmodule Feedproxy.SubscriptionTest do
  use Feedproxy.DataCase

  alias Feedproxy.Subscription

  describe "subscription" do
    @valid_attrs %{
      url: "https://example.com/feed.xml",
      name: "Example Feed",
      feed_type: "rss",
      last_synced_at: ~U[2024-01-28 12:30:26Z]
    }
    @invalid_attrs %{url: nil, name: nil, feed_type: nil, last_synced_at: nil}

    test "changeset with valid attributes" do
      changeset = Subscription.changeset(%Subscription{}, @valid_attrs)
      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      changeset = Subscription.changeset(%Subscription{}, @invalid_attrs)
      refute changeset.valid?
    end

    test "changeset enforces url format" do
      attrs = Map.put(@valid_attrs, :url, "not-a-url")
      changeset = Subscription.changeset(%Subscription{}, attrs)
      assert "must be a valid URL" in errors_on(changeset).url
    end

    test "changeset requires name" do
      attrs = Map.put(@valid_attrs, :name, "")
      changeset = Subscription.changeset(%Subscription{}, attrs)
      assert "can't be blank" in errors_on(changeset).name
    end
  end
end
