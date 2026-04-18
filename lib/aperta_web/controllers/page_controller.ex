defmodule ApertaWeb.PageController do
  use ApertaWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
