defmodule AvesWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use AvesWeb, :html

  embed_templates "page_html/*"
end
