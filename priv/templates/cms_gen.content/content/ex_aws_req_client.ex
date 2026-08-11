defmodule <%= app_module %>.Content.ExAwsReqClient do
  @moduledoc """
  ExAws HTTP client backed by Req, so ExAws S3 operations (which own SigV4
  signing) still flow through Req — and therefore through `Req.Test` stubs in
  tests. The test plug is read from `<%= app_module %>.Content.S3Client`'s app
  env, so the same `plug: {Req.Test, S3Client}` config the tests set intercepts
  the upload.
  """
  @behaviour ExAws.Request.HttpClient

  @impl true
  def request(method, url, body, headers, _http_opts \\ []) do
    opts =
      [
        method: method,
        url: url,
        body: body,
        headers: drop_host(headers),
        decode_body: false,
        retry: false
      ]
      |> maybe_plug()

    case Req.request(opts) do
      {:ok, resp} ->
        {:ok,
         %{
           status_code: resp.status,
           headers: Map.to_list(resp.headers),
           body: to_iodata(resp.body)
         }}

      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  # ExAws sends an explicit `host` header because SigV4 signs it, and Req derives
  # one of its own from the URL. Passing both puts two Host headers on the wire,
  # which S3-compatible servers reject outright:
  #
  #     400 BadRequest — An error occurred when parsing the HTTP request
  #
  # Dropping ours is safe: the value Req derives is the same one that was
  # signed, because it comes from the same URL. Keeping ours instead is not —
  # it would have to win, and Req offers no such guarantee.
  defp drop_host(headers) do
    Enum.reject(headers, fn {name, _value} -> String.downcase(name) == "host" end)
  end

  defp maybe_plug(opts) do
    case Application.get_env(:<%= app %>, <%= app_module %>.Content.S3Client, [])[:plug] do
      nil -> opts
      plug -> Keyword.put(opts, :plug, plug)
    end
  end

  defp to_iodata(body) when is_binary(body), do: body
  defp to_iodata(body), do: :erlang.term_to_binary(body)
end
