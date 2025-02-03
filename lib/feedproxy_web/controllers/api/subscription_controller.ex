defmodule FeedproxyWeb.Api.SubscriptionController do
  use FeedproxyWeb, :controller

  alias Feedproxy.{Subscription, Repo, OpmlParser, FeedSyncer}

  action_fallback FeedproxyWeb.FallbackController

  def index(conn, _params) do
    subscriptions = Repo.all(Subscription)
    render(conn, :index, subscriptions: subscriptions)
  end

  def create(conn, %{"subscription" => subscription_params}) do
    with {:ok, %Subscription{} = subscription} <- create_subscription(subscription_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/subscriptions/#{subscription}")
      |> render(:show, subscription: subscription)
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, subscription} <- fetch_subscription(id) do
      render(conn, :show, subscription: subscription)
    end
  end

  def update(conn, %{"id" => id, "subscription" => subscription_params}) do
    with {:ok, subscription} <- fetch_subscription(id),
         {:ok, %Subscription{} = subscription} <- update_subscription(subscription, subscription_params) do
      render(conn, :show, subscription: subscription)
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, subscription} <- fetch_subscription(id),
         {:ok, %Subscription{}} <- Repo.delete(subscription) do
      send_resp(conn, :no_content, "")
    end
  end

  def import(conn, %{"file" => upload}) do
    with {:ok, content} <- File.read(upload.path),
         feeds <- OpmlParser.parse(content),
         {:ok, subscriptions} <- create_subscriptions_from_opml(feeds) do

      FeedSyncer.sync_now()

      conn
      |> put_status(:created)
      |> render(:index, subscriptions: subscriptions)
    else
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to import OPML: #{inspect(reason)}"})
    end
  end

  # Helper functions
  defp create_subscription(attrs) do
    %Subscription{}
    |> Subscription.changeset(attrs)
    |> Repo.insert()
  end

  defp update_subscription(subscription, attrs) do
    subscription
    |> Subscription.changeset(attrs)
    |> Repo.update()
  end

  defp fetch_subscription(id) do
    case Repo.get(Subscription, id) do
      nil -> {:error, :not_found}
      subscription -> {:ok, subscription}
    end
  end

  defp create_subscriptions_from_opml(feeds) do
    results = Enum.map(feeds, fn feed ->
      %Subscription{}
      |> Subscription.changeset(feed)
      |> Repo.insert(on_conflict: :nothing)
    end)

    successful_inserts = Enum.filter(results, fn
      {:ok, _} -> true
      _ -> false
    end)

    if length(successful_inserts) > 0 do
      {:ok, Repo.all(Subscription)}
    else
      {:error, "No new subscriptions were imported"}
    end
  end
end
