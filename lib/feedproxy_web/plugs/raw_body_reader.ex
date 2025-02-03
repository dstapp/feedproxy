defmodule FeedproxyWeb.Plugs.RawBodyReader do
  def init(opts), do: opts

  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    conn = Plug.Conn.put_private(conn, :raw_body, body)
    {:ok, body, conn}
  end

  def call(conn, _opts), do: conn
end
