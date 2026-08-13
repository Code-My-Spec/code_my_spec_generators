defmodule CodeMySpecGenerators.Generator do
  @moduledoc false

  @doc """
  Detects target app module names from the Mix project configuration.

  Returns a map with:
  - `:app` — OTP app atom
  - `:app_module` — base module name (e.g., "MyApp")
  - `:web_module` — web module name (e.g., "MyAppWeb")
  - `:repo_module` — repo module (e.g., "MyApp.Repo")
  - `:pubsub` — PubSub module (e.g., "MyApp.PubSub")
  - `:endpoint` — endpoint module (e.g., "MyAppWeb.Endpoint")
  - `:mailer` — mailer module (e.g., "MyApp.Mailer")
  """
  def app_config do
    app = Mix.Phoenix.otp_app()
    base = Mix.Phoenix.base()
    web_module = Mix.Phoenix.web_module(base)

    %{
      app: app,
      app_module: base,
      web_module: inspect(web_module),
      repo_module: "#{base}.Repo",
      pubsub: "#{base}.PubSub",
      endpoint: "#{inspect(web_module)}.Endpoint",
      mailer: "#{base}.Mailer"
    }
  end

  @doc """
  Returns the paths to search for template files.

  Searches the code_my_spec_generators app's priv/templates first,
  then falls back to the current directory.
  """
  def template_paths do
    [:code_my_spec_generators, "."]
  end

  @doc """
  Copies template files from priv/templates to the target app.

  Wraps `Mix.Phoenix.copy_from/4` using our template paths.
  """
  def copy_templates(source_dir, binding, mapping) do
    Mix.Phoenix.copy_from(template_paths(), source_dir, binding, mapping)
  end

  @doc """
  Verifies that a prerequisite generator has been run by checking for expected files.
  """
  def ensure_dep_ran!(generator, check_files) do
    missing =
      Enum.reject(check_files, fn file ->
        File.exists?(file)
      end)

    if missing != [] do
      Mix.raise("""
      It looks like #{generator} has not been run yet.
      The following expected files are missing:

      #{Enum.map_join(missing, "\n", &"  * #{&1}")}

      Please run `#{generator}` first.
      """)
    end
  end

  @doc """
  Returns standard EEx binding keyword list from app config.
  """
  def binding do
    config = app_config()

    [
      app: config.app,
      app_module: config.app_module,
      web_module: config.web_module,
      repo_module: config.repo_module,
      pubsub: config.pubsub,
      endpoint: config.endpoint,
      mailer: config.mailer
    ]
  end

  @doc """
  Generates a unique migration timestamp.

  If a migration already carries this second, moves to the next free one.

  That is what this always claimed and did not do: it applied an offset the
  callers never passed, so the whole `cms_gen.*` chain — which runs back to
  back, well inside a second — wrote several migrations with the same version.
  Nothing complained until the app tried to deploy, where it died in the
  migration container with

      ** (Ecto.MigrationError) migrations can't be executed, migration version
      20260813141704 is duplicated

  and the deploy reported "Migration failed (exit 1)". A generated project
  could not migrate at all.

  Reads the directory rather than counting calls, so it holds across separate
  `mix cms_gen.*` invocations — which is how the chain actually runs.
  """
  def migration_timestamp(offset \\ 0) do
    offset
    |> stamp()
    |> next_free()
  end

  defp next_free(stamp) do
    case File.ls(Path.join(["priv", "repo", "migrations"])) do
      {:ok, files} -> advance_past(stamp, MapSet.new(files, &String.slice(&1, 0, 14)))
      _ -> stamp
    end
  end

  defp advance_past(stamp, taken) do
    case MapSet.member?(taken, stamp) do
      true -> stamp |> bump() |> advance_past(taken)
      false -> stamp
    end
  end

  # One second later, via the same calendar arithmetic that built it.
  defp bump(stamp) do
    <<y::binary-4, m::binary-2, d::binary-2, hh::binary-2, mm::binary-2, ss::binary-2>> = stamp

    {{String.to_integer(y), String.to_integer(m), String.to_integer(d)},
     {String.to_integer(hh), String.to_integer(mm), String.to_integer(ss)}}
    |> :calendar.datetime_to_gregorian_seconds()
    |> Kernel.+(1)
    |> :calendar.gregorian_seconds_to_datetime()
    |> format()
  end

  defp stamp(offset) do
    {{y, m, d}, {hh, mm, ss}} =
      :calendar.universal_time()
      |> :calendar.datetime_to_gregorian_seconds()
      |> Kernel.+(offset)
      |> :calendar.gregorian_seconds_to_datetime()

    format({{y, m, d}, {hh, mm, ss}})
  end

  defp format({{y, m, d}, {hh, mm, ss}}) do
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)

  @doc """
  Returns the lib path for the context app.
  """
  def lib_path(rel_path \\ "") do
    app = Mix.Phoenix.otp_app()
    Path.join(["lib", to_string(app), rel_path])
  end

  @doc """
  Returns the web lib path.
  """
  def web_lib_path(rel_path \\ "") do
    app = Mix.Phoenix.otp_app()
    Path.join(["lib", "#{app}_web", rel_path])
  end

  @doc """
  Returns the test path for the context app.
  """
  def test_path(rel_path \\ "") do
    app = Mix.Phoenix.otp_app()
    Path.join(["test", to_string(app), rel_path])
  end

  @doc """
  Returns the web test path.
  """
  def web_test_path(rel_path \\ "") do
    app = Mix.Phoenix.otp_app()
    Path.join(["test", "#{app}_web", rel_path])
  end

  @doc """
  Prints post-generation instructions.
  """
  def print_shell_instructions(instructions) do
    Mix.shell().info("""

    #{instructions}
    """)
  end
end
