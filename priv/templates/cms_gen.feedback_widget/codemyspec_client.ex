defmodule <%= app_module %>.Codemyspec.Client do
  @moduledoc """
  HTTP client for the CodeMySpec API.

  Uses the stored OAuth integration token to communicate with
  the CodeMySpec platform. Requires `cms_gen.integrations` and
  the CodeMySpec provider to be configured.
  """

  alias <%= app_module %>.Integrations

  @doc """
  Creates an issue on the CodeMySpec platform.

  Attrs should include: title, description, severity, and optionally scope.
  The source is automatically set to "user_feedback".
  Attachments should be a list of maps with s3_key, filename, content_type, size.
  """
  def create_issue(scope, attrs, attachments \\ []) do
    with {:ok, token} <- get_token(scope) do
      url = "#{codemyspec_url()}/api/issues"

      issue_params =
        attrs
        |> Map.put("source", "user_feedback")
        |> then(fn params ->
          if attachments != [], do: Map.put(params, "attachments", attachments), else: params
        end)

      body = Jason.encode!(%{"issue" => issue_params})

      headers = [
        {"authorization", "Bearer #{token}"},
        {"content-type", "application/json"}
      ]

      case Req.post(url, body: body, headers: headers) do
        {:ok, %Req.Response{status: 201, body: body}} ->
          {:ok, body["data"]}

        {:ok, %Req.Response{status: status, body: body}} ->
          {:error, %{status: status, body: body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Gets a presigned S3 upload URL from CodeMySpec.

  Returns `{:ok, %{upload_url: url, s3_key: key}}` on success.
  """
  def presign_upload(scope, filename, content_type) do
    with {:ok, token} <- get_token(scope) do
      url = "#{codemyspec_url()}/api/uploads/presign"

      headers = [
        {"authorization", "Bearer #{token}"},
        {"content-type", "application/json"}
      ]

      body = Jason.encode!(%{"filename" => filename, "content_type" => content_type})

      case Req.post(url, body: body, headers: headers) do
        {:ok, %Req.Response{status: 200, body: body}} ->
          {:ok, %{upload_url: body["upload_url"], s3_key: body["s3_key"]}}

        {:ok, %Req.Response{status: status, body: body}} ->
          {:error, %{status: status, body: body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc "Checks if the current user has a CodeMySpec integration."
  def connected?(scope) do
    Integrations.connected?(scope, :codemyspec)
  end

  @doc """
  Fetches a valid access token from the user's CodeMySpec integration.

  Automatically refreshes the token if it has expired and a refresh token is available.
  """
  def get_token(scope) do
    alias <%= app_module %>.Integrations.Integration

    case Integrations.get_integration(scope, :codemyspec) do
      {:ok, %Integration{} = integration} ->
        if Integration.expired?(integration) do
          refresh_token(scope, integration)
        else
          {:ok, integration.access_token}
        end

      _ ->
        {:error, :not_connected}
    end
  end

  defp refresh_token(_scope, %{refresh_token: nil}), do: {:error, :token_expired}
  defp refresh_token(_scope, %{refresh_token: ""}), do: {:error, :token_expired}

  defp refresh_token(scope, integration) do
    provider_config = <%= app_module %>.Integrations.Providers.Codemyspec.config()

    body =
      Jason.encode!(%{
        grant_type: "refresh_token",
        refresh_token: integration.refresh_token,
        client_id: provider_config[:client_id],
        client_secret: provider_config[:client_secret]
      })

    headers = [{"content-type", "application/json"}]

    case Req.post(provider_config[:token_url], body: body, headers: headers) do
      {:ok, %Req.Response{status: 200, body: token_data}} ->
        attrs = %{
          access_token: token_data["access_token"],
          refresh_token: token_data["refresh_token"] || integration.refresh_token,
          expires_at: calculate_expires_at(token_data["expires_in"])
        }

        case Integrations.update_integration(scope, :codemyspec, attrs) do
          {:ok, updated} -> {:ok, updated.access_token}
          {:error, _} -> {:error, :token_refresh_failed}
        end

      _ ->
        {:error, :token_refresh_failed}
    end
  end

  defp calculate_expires_at(nil), do: DateTime.add(DateTime.utc_now(), 7200, :second)
  defp calculate_expires_at(expires_in), do: DateTime.add(DateTime.utc_now(), expires_in, :second)

  defp codemyspec_url do
    Application.fetch_env!(:<%= app %>, :codemyspec_url)
  end
end
