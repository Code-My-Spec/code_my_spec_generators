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

  If called multiple times within the same second, increments by 1 second
  to avoid collisions.
  """
  def migration_timestamp(offset \\ 0) do
    {{y, m, d}, {hh, mm, ss}} =
      :calendar.universal_time()
      |> :calendar.datetime_to_gregorian_seconds()
      |> Kernel.+(offset)
      |> :calendar.gregorian_seconds_to_datetime()

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
