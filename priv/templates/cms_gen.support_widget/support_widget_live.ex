defmodule <%= web_module %>.SupportWidgetLive do
  @moduledoc "Host authentication for the shared CodeMySpec support widget."
  use ClientUtils.SupportWidgetLive
<%= if has_user_auth do %>
  on_mount {<%= web_module %>.UserAuth, :mount_current_scope}
<% end %>
end
