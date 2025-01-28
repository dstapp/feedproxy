defmodule FeedproxyWeb.FallbackController do
  use FeedproxyWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: FeedproxyWeb.ErrorJSON)
    |> render(:error, changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: FeedproxyWeb.ErrorJSON)
    |> render(:error, message: "Not Found")
  end
end
