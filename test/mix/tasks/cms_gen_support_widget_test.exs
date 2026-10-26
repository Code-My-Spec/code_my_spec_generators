defmodule Mix.Tasks.CmsGen.SupportWidgetTest do
  use ExUnit.Case, async: false

  import CodeMySpecGenerators.GeneratorTestHelpers

  @moduletag :generator

  setup do
    tmp = create_tmp_dir("cms_gen_support_widget")
    write_phoenix_skeleton(tmp)
    Mix.shell(Mix.Shell.Process)

    on_exit(fn ->
      Mix.shell(Mix.Shell.IO)
      cleanup_tmp_dir(tmp)
    end)

    %{tmp: tmp}
  end

  describe "cms_gen.support_widget" do
    test "generates the verify controller and routes it outside every pipeline", %{tmp: tmp} do
      run_generator(tmp)

      assert_file(Path.join(tmp, "lib/site_web/controllers/widget_verify_controller.ex"), [
        "defmodule SiteWeb.WidgetVerifyController",
        "alias Site.CodeMySpec.Widget",
        ~s|["Bearer " <> provided] <- get_req_header(conn, "authorization")|,
        "Application.get_env(:site, :deploy_key)",
        "put_status(:unauthorized)",
        "Widget.verify("
      ])

      router = File.read!(Path.join(tmp, "lib/site_web/router.ex"))
      assert router =~ ~s|scope "/_cms", SiteWeb do|
      assert router =~ ~s|post "/verify/widget", WidgetVerifyController, :create|
      refute router =~ ~r/scope "\/_cms".*pipe_through/s
      assert router =~ ~s|get "/health", HealthController, :show|
    end

    test "the widget can send a message and wait for CodeMySpec to store it", %{tmp: tmp} do
      run_generator(tmp)

      assert_file(Path.join(tmp, "lib/site/code_my_spec/widget.ex"), [
        "def verify(body, origin, timeout \\\\ 10_000)",
        ~s|@verify_user "cms-verify"|,
        "{:send_confirmed, body}"
      ])

      assert_file(Path.join(tmp, "lib/site/code_my_spec/widget_client.ex"), [
        "def handle_call({:send_confirmed, body}, from, socket)",
        "when is_map_key(awaiting, ref)",
        "GenServer.reply(from, {:error, :disconnected})"
      ])
    end

    test "every generated file parses", %{tmp: tmp} do
      run_generator(tmp)

      for path <- [
            "lib/site/code_my_spec/widget.ex",
            "lib/site/code_my_spec/widget_client.ex",
            "lib/site_web/live/support_widget_live.ex",
            "lib/site_web/controllers/widget_verify_controller.ex",
            "lib/site_web/router.ex"
          ] do
        assert {:ok, _} = Code.string_to_quoted(File.read!(Path.join(tmp, path))), path
      end
    end

    test "re-running leaves an already-routed router alone", %{tmp: tmp} do
      run_generator(tmp)
      routed = File.read!(Path.join(tmp, "lib/site_web/router.ex"))

      for path <- generated_files(), do: File.rm!(Path.join(tmp, path))
      run_generator(tmp)

      assert File.read!(Path.join(tmp, "lib/site_web/router.ex")) == routed
    end
  end

  defp generated_files do
    [
      "lib/site/code_my_spec/widget.ex",
      "lib/site/code_my_spec/widget_client.ex",
      "lib/site_web/live/support_widget_live.ex",
      "lib/site_web/controllers/widget_verify_controller.ex"
    ]
  end

  defp run_generator(tmp) do
    Mix.Project.in_project(:site, tmp, fn _ -> Mix.Task.rerun("cms_gen.support_widget", []) end)
  end

  defp write_phoenix_skeleton(tmp) do
    files = %{
      "mix.exs" => """
      defmodule Site.MixProject do
        use Mix.Project

        def project, do: [app: :site, version: "0.1.0", deps: deps()]

        defp deps do
          [
            {:phoenix, "~> 1.8"},
          ]
        end
      end
      """,
      "lib/site/application.ex" => """
      defmodule Site.Application do
        use Application

        def start(_type, _args) do
          children = [
            {Phoenix.PubSub, name: Site.PubSub},
            SiteWeb.Endpoint
          ]

          Supervisor.start_link(children, strategy: :one_for_one)
        end
      end
      """,
      "lib/site_web/router.ex" => """
      defmodule SiteWeb.Router do
        use SiteWeb, :router

        pipeline :browser do
          plug :accepts, ["html"]
        end

        scope "/", SiteWeb do
          get "/health", HealthController, :show
        end
      end
      """,
      "lib/site_web/components/layouts/root.html.heex" =>
        "<html>\n  <body>\n  </body>\n</html>\n",
      "config/runtime.exs" => "import Config\n"
    }

    for {path, contents} <- files do
      full = Path.join(tmp, path)
      File.mkdir_p!(Path.dirname(full))
      File.write!(full, contents)
    end
  end
end
