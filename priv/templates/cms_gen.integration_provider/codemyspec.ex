defmodule <%= app_module %>.Integrations.Providers.Codemyspec do
  @moduledoc """
  CodeMySpec OAuth provider implementation.

  Connects to the CodeMySpec platform for issue reporting and feedback.

  Configure in your runtime config:

      config :<%= app %>,
        codemyspec_url: System.get_env("CODEMYSPEC_URL") || "https://codemyspec.com",
        codemyspec_client_id: System.get_env("CODEMYSPEC_CLIENT_ID"),
        codemyspec_client_secret: System.get_env("CODEMYSPEC_CLIENT_SECRET")
  """

  require Logger

  @behaviour <%= app_module %>.Integrations.Providers.Behaviour

  @impl true
  def config(redirect_uri) when is_binary(redirect_uri) and redirect_uri != "" do
    base_url = Application.fetch_env!(:<%= app %>, :codemyspec_url)
    client_id = Application.fetch_env!(:<%= app %>, :codemyspec_client_id)
    client_secret = Application.fetch_env!(:<%= app %>, :codemyspec_client_secret)

    [
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_uri,
      base_url: base_url,
      authorize_url: "#{base_url}/oauth/authorize",
      token_url: "#{base_url}/oauth/token",
      user_url: "#{base_url}/api/me",
      authorization_params: [
        scope: "read write"
      ]
    ]
  end

  def config(other) do
    raise ArgumentError,
          "Codemyspec.config/1 requires a non-empty redirect_uri string passed from the " <>
            "web layer (e.g. <%= endpoint %>.url() <> callback_path); got: " <>
            inspect(other)
  end

  @impl true
  def strategy, do: Assent.Strategy.OAuth2

  @impl true
  def normalize_user(user_data) when is_map(user_data) do
    {:ok,
     %{
       provider_user_id: Map.get(user_data, "id") |> to_string(),
       email: Map.get(user_data, "email"),
       name: Map.get(user_data, "email"),
       username: Map.get(user_data, "email"),
       avatar_url: nil
     }}
  end

  def normalize_user(_user_data), do: {:error, :invalid_user_data}
end
