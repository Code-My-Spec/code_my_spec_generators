defmodule <%= app_module %>.Vault do
  use Cloak.Vault, otp_app: :<%= app %>
end
