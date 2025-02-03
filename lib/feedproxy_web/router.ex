defmodule FeedproxyWeb.Router do
  use FeedproxyWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FeedproxyWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug FeedproxyWeb.Plugs.RawBodyReader
    plug :accepts, ["json"]
  end

  # scope "/", FeedproxyWeb do
  #   pipe_through :browser

  #   get "/", PageController, :home
  # end

  scope "/api", FeedproxyWeb.Api do
    pipe_through :api

    resources "/subscriptions", SubscriptionController
    scope "/feed-items" do
      get "/", FeedItemController, :index, as: :index
      post "/sync", FeedItemController, :sync, as: :sync
    end
    post "/subscriptions/import", SubscriptionController, :import
  end

  scope "/api/greader.php", FeedproxyWeb do
    pipe_through :api

    # Auth endpoints
    post "/accounts/ClientLogin", GreaderApiController, :client_login
    get "/reader/api/0/token", GreaderApiController, :token

    # User info
    get "/reader/api/0/user-info", GreaderApiController, :user_info

    # Subscription management
    get "/reader/api/0/subscription/list", GreaderApiController, :subscription_list
    get "/reader/api/0/tag/list", GreaderApiController, :tag_list

    # Stream contents
    get "/reader/api/0/stream/contents/*streamId", GreaderApiController, :stream_contents
    post "/reader/api/0/stream/contents/*streamId", GreaderApiController, :stream_contents

    # Item state management
    post "/reader/api/0/edit-tag", GreaderApiController, :edit_tag
    post "/reader/api/0/mark-all-as-read", GreaderApiController, :mark_all_as_read

    # Unread counts
    get "/reader/api/0/unread-count", GreaderApiController, :unread_count

    # Stream item IDs
    get "/reader/api/0/stream/items/ids", GreaderApiController, :stream_item_ids

    # Stream item contents
    post "/reader/api/0/stream/items/contents", GreaderApiController, :stream_contents
  end

  # Other scopes may use custom stacks.
  # scope "/api", FeedproxyWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:feedproxy, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FeedproxyWeb.Telemetry
    end
  end
end
