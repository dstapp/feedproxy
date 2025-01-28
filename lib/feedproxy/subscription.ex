defmodule Feedproxy.Subscription do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "subscriptions" do
    field :name, :string
    field :url, :string
    field :feed_type, :string
    field :last_synced_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:name, :url, :feed_type, :last_synced_at])
    |> validate_required([:name, :url, :feed_type, :last_synced_at])
  end
end
