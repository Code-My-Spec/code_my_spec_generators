defmodule <%= web_module %>.BlogController do
  @moduledoc """
  Serves the content a publish pushed here.

  The pull endpoint is only half of publishing: content that arrives and is
  never rendered is indistinguishable, from outside, from content that never
  arrived. This is the half a reader sees, and the half a publish verifies —
  the publishing server fetches a post back from here to prove it rendered
  before it calls the publish done.

  Deliberately plain. It reads through `<%= app_module %>.Content`, which
  applies the publish window and the protected flag, and renders the processed
  HTML the publisher already produced. Anything more opinionated — layouts,
  styling, feeds — belongs in the application rather than in a generator.
  """

  use <%= web_module %>, :controller

  alias <%= app_module %>.Content

  def index(conn, _params) do
    scope = conn.assigns[:current_scope]

    render(conn, :index, posts: Content.list_published_content(scope, :blog))
  end

  def show(conn, %{"slug" => slug}) do
    scope = conn.assigns[:current_scope]

    scope
    |> Content.get_content_by_slug(slug, :blog)
    |> render_post(conn)
  end

  # A slug that is unknown, not yet published, or expired is a 404 — not a
  # redirect and not a friendly empty page. A reader following a link to a post
  # that is not live should be told it is not there, and a publish that verifies
  # its own render needs the difference to be visible in the status code.
  defp render_post(nil, conn) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(404, "Not Found")
    |> halt()
  end

  defp render_post({:error, _reason}, conn), do: render_post(nil, conn)

  defp render_post({:ok, post}, conn), do: render(conn, :show, post: post)

  defp render_post(post, conn), do: render(conn, :show, post: post)
end
