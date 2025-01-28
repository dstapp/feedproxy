defmodule FeedproxyWeb.Api.SubscriptionJSON do
  alias Feedproxy.Subscription

  @doc """
  Renders a list of subscriptions.
  """
  def index(%{subscriptions: subscriptions}) do
    %{data: for(subscription <- subscriptions, do: data(subscription))}
  end

  @doc """
  Renders a single subscription.
  """
  def show(%{subscription: subscription}) do
    %{data: data(subscription)}
  end

  defp data(%Subscription{} = subscription) do
    %{
      id: subscription.id,
      name: subscription.name,
      url: subscription.url,
      feed_type: subscription.feed_type,
      last_synced_at: subscription.last_synced_at
    }
  end
end
