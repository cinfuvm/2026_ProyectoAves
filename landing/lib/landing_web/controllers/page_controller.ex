defmodule LandingWeb.PageController do
  use LandingWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
