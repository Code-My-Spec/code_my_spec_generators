defmodule <%= app_module %>.Content.S3Client do
  @moduledoc """
  Uploads objects to an S3/R2 bucket via `ExAws.S3`, which owns SigV4 signing.
  Credentials come from the local `:ex_aws` config.

  HTTP flows through `<%= app_module %>.Content.ExAwsReqClient` (a Req-backed
  ExAws client), so tests intercept uploads by configuring a `Req.Test` plug
  under this module's app env:

      Application.put_env(:<%= app %>, #{inspect(__MODULE__)}, plug: {Req.Test, #{inspect(__MODULE__)}})

  Optional per-deployment S3 config (e.g. an R2 endpoint) can be set under
  `:s3_config` in this module's app env and is merged into the ExAws request.

  Requires `{:ex_aws, "~> 2.5"}` and `{:ex_aws_s3, "~> 2.5"}` in your deps.
  """

  alias <%= app_module %>.Content.ExAwsReqClient

  @doc """
  PUT `body` to `s3://<bucket>/<key>`. Returns `:ok` on success, `{:error, _}`
  otherwise.

  Pass `credentials:` (a keyword list of `:access_key_id`, `:secret_access_key`,
  `:region`) to sign with explicit keys rather than the global `:ex_aws` app
  env. Blank entries should be dropped by the caller so ExAws falls back.
  """
  @spec put_object(String.t(), String.t(), iodata(), keyword()) :: :ok | {:error, term()}
  def put_object(bucket, key, body, opts \\ []) do
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")
    credentials = Keyword.get(opts, :credentials, [])

    bucket
    |> ExAws.S3.put_object(key, body, content_type: content_type)
    |> ExAws.request(request_config(credentials))
    |> case do
      {:ok, _response} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  GET `s3://<bucket>/<key>`. Returns `{:ok, body}` or `{:error, _}`. Flows
  through `ExAwsReqClient` so tests intercept it with the same plug as uploads.
  """
  @spec get_object(String.t(), String.t(), keyword()) :: {:ok, binary()} | {:error, term()}
  def get_object(bucket, key, opts \\ []) do
    credentials = Keyword.get(opts, :credentials, [])

    bucket
    |> ExAws.S3.get_object(key)
    |> ExAws.request(request_config(credentials))
    |> case do
      {:ok, %{body: body}} -> {:ok, body}
      {:error, reason} -> {:error, reason}
    end
  end

  defp request_config(credentials) do
    extra = Application.get_env(:<%= app %>, __MODULE__, [])[:s3_config] || []

    [http_client: ExAwsReqClient]
    |> Keyword.merge(extra)
    |> Keyword.merge(credentials)
  end
end
