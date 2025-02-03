defmodule Feedproxy.Repo.Migrations.CreateFeedItems do
  use Ecto.Migration

  def change do
    create table(:feed_items) do
      add :title, :string
      add :published_at, :utc_datetime_usec
      add :url, :string
      add :excerpt, :string
      add :is_read, :boolean, default: false, null: false
      add :is_starred, :boolean, default: false, null: false
      add :subscription_id, references(:subscriptions, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:feed_items, [:subscription_id])
    create unique_index(:feed_items, [:url])
  end
end
