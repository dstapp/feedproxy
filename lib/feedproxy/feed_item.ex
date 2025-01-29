defmodule Feedproxy.FeedItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "feed_items" do
    field :title, :string
    field :url, :string
    field :published_at, :utc_datetime
    field :excerpt, :string
    field :is_read, :boolean, default: false
    field :is_starred, :boolean, default: false
    field :subscription_id, :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(feed_item, attrs) do
    feed_item
    |> cast(attrs, [:title, :published_at, :url, :excerpt, :is_read, :is_starred])
    |> validate_required([:title, :published_at, :url])
  end
end
