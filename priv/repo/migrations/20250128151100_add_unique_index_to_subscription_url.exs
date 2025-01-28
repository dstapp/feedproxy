defmodule Feedproxy.Repo.Migrations.AddUniqueIndexToSubscriptionUrl do
  use Ecto.Migration

  def change do
    create unique_index(:subscriptions, [:url])
  end
end
