defmodule FeedproxyWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use FeedproxyWeb, :controller` and
  `use FeedproxyWeb, :live_view`.
  """
  use FeedproxyWeb, :html

  embed_templates "layouts/*"
end
