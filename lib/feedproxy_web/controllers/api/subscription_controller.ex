defmodule FeedproxyWeb.Api.SubscriptionController do
  use FeedproxyWeb, :controller

  alias Feedproxy.Subscription
  alias Feedproxy.Repo

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
end
