defmodule <%= app_module %>.Encrypted.Binary do
  use Cloak.Ecto.Binary, vault: <%= app_module %>.Vault
end
