defmodule Feedproxy.Repo do
  use Ecto.Repo,
    otp_app: :feedproxy,
    adapter: Ecto.Adapters.SQLite3
end
