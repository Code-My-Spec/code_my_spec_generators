defmodule <%= web_module %>.ContentSyncController do
  @moduledoc """
  Receives content from the CodeMySpec publishing flow into this appliance.

  Two entrypoints:

    * `sync/2` — the publishing server PUSHes the whole content corpus in the
      request body.
    * `pull/2` — the publishing server sends a trigger with a `manifest_url`;
      this app PULLs the manifest and content blob itself, verifies the blob
      hash, and replaces local content.

  Both are authenticated by a deployment key (Bearer token matching the
  `:deploy_key` config, sourced from the `DEPLOY_KEY` env var) rather than
  OAuth — the caller is the publishing server, not an end user.
  """

  use <%= web_module %>, :controller

  alias <%= app_module %>.Content

  @doc """
  Handles a content sync POST from the publishing server.

  ## Expected payload

      %{
        "content" => [%{slug, title, content_type, processed_content, ...}, ...],
        "synced_at" => ISO8601 datetime
      }

  ## Authentication

  Requires `Authorization: Bearer <DEPLOY_KEY>` matching the server's configured
  `:deploy_key`.
  """
  def sync(conn, %{"content" => content_list, "synced_at" => _synced_at}) do
    with :ok <- validate_deploy_key(conn),
         {:ok, _result} <- Content.sync_content(content_list) do
      conn
      |> put_status(:ok)
      |> json(%{
        status: "success",
        synced_count: length(content_list),
        message: "Content synced successfully"
      })
    else
      {:error, :unauthorized} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{status: "error", error: "Invalid deployment key"})

      {:error, :missing_deploy_key} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{status: "error", error: "Missing deployment key"})

      {:error, :deploy_key_not_configured} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{status: "error", error: "Deploy key not configured on server"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", error: inspect(reason)})
    end
  end

  def sync(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{status: "error", error: "Missing required parameters: content, synced_at"})
  end

  @doc """
  Pull trigger. Validates the deploy key, then starts an async sync that fetches
  the manifest from `manifest_url`, verifies the blob hash, and atomically
  replaces local content. Returns 202 immediately; auth failures return 401.
  """
  def pull(conn, %{"manifest_url" => manifest_url}) do
    case validate_deploy_key(conn) do
      :ok ->
        run_pull(manifest_url)

        conn
        |> put_status(:accepted)
        |> json(%{status: "accepted", sync_id: Ecto.UUID.generate()})

      {:error, :unauthorized} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{status: "error", error: "Invalid deployment key"})

      {:error, :missing_deploy_key} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{status: "error", error: "Missing deployment key"})

      {:error, :deploy_key_not_configured} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{status: "error", error: "Deploy key not configured on server"})
    end
  end

  def pull(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{status: "error", error: "Missing required parameter: manifest_url"})
  end

  # Run the pull async in production; synchronously in tests (so it shares the
  # ExUnit sandbox connection instead of racing the test process's lifetime).
  defp run_pull(manifest_url) do
    if Application.get_env(:<%= app %>, :content_pull_async, true) do
      Task.start(fn -> <%= app_module %>.Content.Pull.run(manifest_url) end)
    else
      <%= app_module %>.Content.Pull.run(manifest_url)
    end
  end

  # Authentication ------------------------------------------------------------

  @spec validate_deploy_key(Plug.Conn.t()) :: :ok | {:error, atom()}
  defp validate_deploy_key(conn) do
    with {:ok, expected_key} <- get_expected_deploy_key(),
         {:ok, provided_key} <- extract_bearer_token(conn) do
      if secure_compare(expected_key, provided_key) do
        :ok
      else
        {:error, :unauthorized}
      end
    end
  end

  @spec get_expected_deploy_key() :: {:ok, String.t()} | {:error, :deploy_key_not_configured}
  defp get_expected_deploy_key do
    case Application.get_env(:<%= app %>, :deploy_key) do
      nil -> {:error, :deploy_key_not_configured}
      "" -> {:error, :deploy_key_not_configured}
      key -> {:ok, key}
    end
  end

  @spec extract_bearer_token(Plug.Conn.t()) :: {:ok, String.t()} | {:error, :missing_deploy_key}
  defp extract_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> {:error, :missing_deploy_key}
    end
  end

  # Constant-time comparison to avoid leaking the key via timing.
  @spec secure_compare(String.t(), String.t()) :: boolean()
  defp secure_compare(left, right) do
    if byte_size(left) == byte_size(right) do
      Plug.Crypto.secure_compare(left, right)
    else
      Plug.Crypto.secure_compare(left, left)
      false
    end
  end
end
