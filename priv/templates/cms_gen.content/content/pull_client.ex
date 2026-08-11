defmodule <%= app_module %>.Content.PullClient do
  @moduledoc """
  Pulls the manifest and content blob out of the publisher's bucket after a
  pull trigger.

  Through S3 with this app's own credentials, not a plain HTTP GET. Both sides
  hold keys for the same bucket — the publishing server writes with its pair,
  this app reads with its own — so the bucket stays private and nothing is
  served to the public internet to make the handoff work.

  It previously fetched the URL unauthenticated, which quietly required the
  content bucket to be world-readable. That is a large thing to require for a
  transfer between two systems that both already have credentials, and it fails
  closed in the worst way: a private bucket answers 403 and the pull aborts,
  while the trigger has already been accepted and the objects are sitting in
  the bucket. From outside, a publish that never arrives looks exactly like one
  that never ran.

  The trigger still carries a URL, because that is what the publisher knows and
  what the endpoint's contract says. The bucket and key are read back out of it
  — path-style, which is what every S3-compatible provider we target uses.

  Credentials and endpoint live on `<%= app_module %>.Content.S3Client`'s own
  `:s3_config`, which is also what tests intercept.
  """

  alias <%= app_module %>.Content.S3Client

  @doc """
  Fetch the object `url` points at, returning its raw bytes.

  No decoding: the caller hashes exactly what it received and compares that to
  the manifest, so a transformation here would break the integrity check it is
  there to support.
  """
  @spec fetch(String.t()) :: {:ok, binary()} | {:error, term()}
  def fetch(url) do
    url
    |> parse_object()
    |> fetch_object()
  end

  # `https://endpoint/bucket/key` — path-style. A URL that carries no bucket is
  # reported as such rather than guessed at: pulling the wrong object would
  # replace this site's content with somebody else's.
  defp parse_object(url) do
    case URI.parse(url) do
      %URI{path: "/" <> rest} -> split_object(String.split(rest, "/", parts: 2))
      _ -> {:error, {:unparseable_object_url, url}}
    end
  end

  defp split_object([bucket, key]) when bucket != "" and key != "", do: {:ok, bucket, key}
  defp split_object(parts), do: {:error, {:unparseable_object_url, Enum.join(parts, "/")}}

  defp fetch_object({:error, reason}), do: {:error, reason}

  # No options: `S3Client` reads its own `:s3_config` — endpoint, region and
  # this app's key pair — from app env, which is the one place those belong.
  defp fetch_object({:ok, bucket, key}) do
    S3Client.get_object(bucket, key)
  end
end
