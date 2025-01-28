defmodule Feedproxy.Repo.Migrations.CreateSubscriptions do
  use Ecto.Migration

  def change do
    create table(:subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :url, :string
      add :feed_type, :string
      add :last_synced_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end
  end
end
