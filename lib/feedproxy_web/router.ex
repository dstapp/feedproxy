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
    plug :accepts, ["json"]
  end

  scope "/", FeedproxyWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/api", FeedproxyWeb.Api do
    pipe_through :api

    resources "/subscriptions", SubscriptionController
    scope "/feed-items" do
      get "/", FeedItemController, :index, as: :index
      post "/sync", FeedItemController, :sync, as: :sync
    end
    post "/subscriptions/import", SubscriptionController, :import
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
