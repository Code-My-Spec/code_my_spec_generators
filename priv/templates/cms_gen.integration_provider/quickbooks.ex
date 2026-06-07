defmodule <%= app_module %>.Integrations.Providers.QuickBooks do
  @moduledoc """
  QuickBooks Online OAuth provider implementation using Assent.Strategy.OAuth2.

  Configures OAuth with `com.intuit.quickbooks.accounting` scope for accessing
  QuickBooks Online company data. Uses the Intuit OAuth 2.0 endpoints.

  Configure the client credentials in your runtime config:

      config :<%= app %>,
        quickbooks_client_id: System.get_env("QUICKBOOKS_CLIENT_ID"),
        quickbooks_client_secret: System.get_env("QUICKBOOKS_CLIENT_SECRET")
  """

  require Logger

  @behaviour <%= app_module %>.Integrations.Providers.Behaviour

  @authorize_url "https://appcenter.intuit.com/connect/oauth2"
  @token_url "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer"
  @revoke_url "https://developer.api.intuit.com/v2/oauth2/tokens/revoke"

  @impl true
  def config(redirect_uri) when is_binary(redirect_uri) and redirect_uri != "" do
    client_id = Application.fetch_env!(:<%= app %>, :quickbooks_client_id)
    client_secret = Application.fetch_env!(:<%= app %>, :quickbooks_client_secret)

    [
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_uri,
      base_url: "https://oauth.platform.intuit.com",
      authorize_url: @authorize_url,
      token_url: @token_url,
      auth_method: :client_secret_basic,
      authorization_params: [
        scope: "com.intuit.quickbooks.accounting"
      ]
    ]
  end

  def config(other) do
    raise ArgumentError,
          "QuickBooks.config/1 requires a non-empty redirect_uri string passed from the " <>
            "web layer (e.g. <%= endpoint %>.url() <> callback_path); got: " <> inspect(other)
  end

  @impl true
  def strategy, do: Assent.Strategy.OAuth2

  @impl true
  def normalize_user(user_data) when is_map(user_data) do
    provider_user_id =
      case extract_provider_user_id(user_data) do
        {:ok, id} -> id
        {:error, _} -> "quickbooks_user"
      end

    email = Map.get(user_data, "email")

    {:ok,
     %{
       provider_user_id: provider_user_id,
       email: email,
       name: Map.get(user_data, "name") || Map.get(user_data, "givenName"),
       username: email,
       avatar_url: nil,
       realm_id: Map.get(user_data, "realmId")
     }}
  end

  def normalize_user(_user_data), do: {:error, :invalid_user_data}

  @impl true
  def revoke_token(token) when is_binary(token) do
    client_id = Application.fetch_env!(:<%= app %>, :quickbooks_client_id)
    client_secret = Application.fetch_env!(:<%= app %>, :quickbooks_client_secret)
    credentials = Base.encode64("#{client_id}:#{client_secret}")
    body = Jason.encode!(%{"token" => token})

    headers = [
      {~c"authorization", ~c"Basic #{credentials}"},
      {~c"accept", ~c"application/json"},
      {~c"content-type", ~c"application/json"}
    ]

    request = {String.to_charlist(@revoke_url), headers, ~c"application/json", body}

    case :httpc.request(:post, request, [], []) do
      {:ok, {{_version, 200, _reason}, _headers, _body}} ->
        Logger.info("QuickBooks token revoked successfully")
        :ok

      {:ok, {{_version, status, _reason}, _headers, resp_body}} ->
        Logger.warning("QuickBooks token revocation returned #{status}: #{inspect(resp_body)}")
        {:error, {:revocation_failed, status}}

      {:error, reason} ->
        Logger.warning("QuickBooks token revocation request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp extract_provider_user_id(%{"sub" => sub}) when is_binary(sub) and byte_size(sub) > 0,
    do: {:ok, sub}

  defp extract_provider_user_id(%{"sub" => sub}) when is_integer(sub),
    do: {:ok, Integer.to_string(sub)}

  defp extract_provider_user_id(_user_data), do: {:error, :missing_provider_user_id}
end
