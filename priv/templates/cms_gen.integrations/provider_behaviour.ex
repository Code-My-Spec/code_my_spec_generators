defmodule <%= app_module %>.Integrations.Providers.Behaviour do
  @moduledoc """
  Behaviour for OAuth integration providers. `config/1` receives the absolute
  redirect URI from the web layer.
  """

  @callback config(redirect_uri :: String.t()) :: Keyword.t()
  @callback strategy() :: module()
  @callback normalize_user(user_data :: map()) :: {:ok, map()} | {:error, term()}
  @callback revoke_token(token :: String.t()) :: :ok | {:error, term()}
  @optional_callbacks [revoke_token: 1]
end
