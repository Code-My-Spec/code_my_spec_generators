defmodule <%= app_module %>.Integrations.Providers.Facebook do
  @moduledoc """
  Facebook OAuth provider implementation using Assent.Strategy.Facebook.

  Configure the client credentials in your runtime config:

      config :<%= app %>,
        facebook_app_id: System.get_env("FACEBOOK_APP_ID"),
        facebook_app_secret: System.get_env("FACEBOOK_APP_SECRET")
  """

  require Logger

  @behaviour <%= app_module %>.Integrations.Providers.Behaviour

  @callback_path "/integrations/oauth/callback/facebook"

  @impl true
  def config do
    client_id = Application.fetch_env!(:<%= app %>, :facebook_app_id)
    client_secret = Application.fetch_env!(:<%= app %>, :facebook_app_secret)
    redirect_uri = <%= endpoint %>.url() <> @callback_path

    [
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_uri,
      authorization_params: [
        scope: "email"
      ]
    ]
  end

  @impl true
  def strategy, do: Assent.Strategy.Facebook

  @impl true
  def normalize_user(user_data) when is_map(user_data) do
    with {:ok, provider_user_id} <- extract_provider_user_id(user_data) do
      email = Map.get(user_data, "email")

      {:ok,
       %{
         provider_user_id: provider_user_id,
         email: email,
         name: Map.get(user_data, "name"),
         username: email,
         avatar_url: Map.get(user_data, "picture")
       }}
    end
  end

  def normalize_user(_user_data), do: {:error, :invalid_user_data}

  defp extract_provider_user_id(%{"sub" => sub}) when is_binary(sub) and byte_size(sub) > 0,
    do: {:ok, sub}

  defp extract_provider_user_id(%{"sub" => sub}) when is_integer(sub),
    do: {:ok, Integer.to_string(sub)}

  defp extract_provider_user_id(_user_data), do: {:error, :missing_provider_user_id}
end
