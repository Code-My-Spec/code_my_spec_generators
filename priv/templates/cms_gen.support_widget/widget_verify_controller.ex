defmodule <%= web_module %>.WidgetVerifyController do
  @moduledoc "Host route for the shared widget verification endpoint."
  use <%= web_module %>, :controller
  defdelegate create(conn, params), to: ClientUtils.WidgetVerifyController
end
