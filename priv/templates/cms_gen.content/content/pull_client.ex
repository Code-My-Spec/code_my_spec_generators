defmodule <%= app_module %>.Content.PullClient do
  @moduledoc """
  Req client this app uses to PULL the manifest and content blob from the
  publisher's S3 bucket after a pull trigger. Non-S3 outbound HTTP (the URLs are
  CDN/S3 GETs), so it stays a thin Req client.

  In tests a `Req.Test` plug configured under this module's app env intercepts
  the GETs.

  Config (`Application.get_env(:<%= app %>, #{inspect(__MODULE__)})`):
    * `:plug` — a `{Req.Test, name}` plug (tests only)
  """

  @doc """
  GET `url`, returning the raw response body bytes (no decoding — the caller
  hashes the exact bytes). Returns `{:ok, binary}` on 200, `{:error, _}`
  otherwise.
  """
  @spec fetch(String.t()) :: {:ok, binary()} | {:error, term()}
  def fetch(url) do
    [method: :get, url: url, decode_body: false, retry: false]
    |> maybe_plug()
    |> Req.request()
    |> case do
      {:ok, %{status: 200, body: body}} -> {:ok, IO.iodata_to_binary(body)}
      {:ok, %{status: status}} -> {:error, {:status, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_plug(opts) do
    case Application.get_env(:<%= app %>, __MODULE__, [])[:plug] do
      nil -> opts
      plug -> Keyword.put(opts, :plug, plug)
    end
  end
end
