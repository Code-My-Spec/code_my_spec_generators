defmodule <%= app_module %>.Integrations.Providers.<%= provider_module %> do
  @moduledoc """
  <%= display_name %> OAuth provider implementation.

  Configure the client credentials in your runtime config:

      config :<%= app %>,
        <%= provider_key %>_client_id: System.get_env("<%= String.upcase(provider_key) %>_CLIENT_ID"),
        <%= provider_key %>_client_secret: System.get_env("<%= String.upcase(provider_key) %>_CLIENT_SECRET")
  """

  require Logger

  @behaviour <%= app_module %>.Integrations.Providers.Behaviour

  @callback_path "/integrations/oauth/callback/<%= provider_key %>"

  @impl true
  def config do
    client_id = Application.fetch_env!(:<%= app %>, :<%= provider_key %>_client_id)
    client_secret = Application.fetch_env!(:<%= app %>, :<%= provider_key %>_client_secret)
    redirect_uri = <%= endpoint %>.url() <> @callback_path

    [
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_uri,
      authorization_params: [
        scope: "read"
      ]
    ]
  end

  @impl true
  def strategy, do: Assent.Strategy.OAuth2

  @impl true
  def normalize_user(user_data) when is_map(user_data) do
    {:ok,
     %{
       provider_user_id: Map.get(user_data, "sub") || Map.get(user_data, "id") |> to_string(),
       email: Map.get(user_data, "email"),
       name: Map.get(user_data, "name"),
       username: Map.get(user_data, "login") || Map.get(user_data, "email"),
       avatar_url: Map.get(user_data, "avatar_url") || Map.get(user_data, "picture")
     }}
  end

  def normalize_user(_user_data), do: {:error, :invalid_user_data}
end
