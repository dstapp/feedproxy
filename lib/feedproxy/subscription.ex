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

  @doc """
  Changeset for external API operations (create/update).
  Does not allow last_synced_at to be set from external input.
  """
  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:name, :url, :feed_type])
    |> validate_required([:name, :url, :feed_type])
    |> validate_url(:url)
    |> unique_constraint(:url, message: "Subscription already exists for this URL")
  end

  @doc """
  Internal changeset for updating sync timestamp.
  """
  def sync_changeset(subscription, timestamp) do
    subscription
    |> change(last_synced_at: timestamp)
  end

  defp validate_url(changeset, field) do
    validate_change(changeset, field, fn _, url ->
      case URI.parse(url) do
        %URI{scheme: scheme, host: host}
        when scheme in ["http", "https"] and not is_nil(host) ->
          []
        _ ->
          [{field, "must be a valid URL"}]
      end
    end)
  end
end
