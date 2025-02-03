defmodule Feedproxy.Repo.Migrations.CreateSubscriptions do
  use Ecto.Migration

  def change do
    create table(:subscriptions) do
      add :name, :string
      add :url, :string
      add :feed_type, :string
      add :last_synced_at, :utc_datetime_usec

      timestamps(type: :utc_datetime)
    end
  end
end
