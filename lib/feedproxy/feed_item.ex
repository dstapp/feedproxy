defmodule Feedproxy.FeedItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  schema "feed_items" do
    field :title, :string
    field :url, :string
    field :published_at, :utc_datetime_usec
    field :excerpt, :string
    field :is_read, :boolean, default: false
    field :is_starred, :boolean, default: false

    belongs_to :subscription, Feedproxy.Subscription

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(feed_item, attrs) do
    feed_item
    |> cast(attrs, [:title, :published_at, :url, :excerpt, :is_read, :is_starred, :subscription_id])
    |> validate_required([:title, :published_at, :url])
    |> foreign_key_constraint(:subscription_id)
  end
end
