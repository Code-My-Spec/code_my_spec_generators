defmodule CodeMySpecGenerators.Injector do
  @moduledoc false

  @doc """
  Injects route blocks into the router file.

  Finds the specified anchor point and injects the routes after it.
  Returns `{:ok, new_content}`, `:already_injected`, or `{:error, :unable_to_inject}`.
  """
  def inject_routes(file_content, routes_to_inject) do
    inject_unless_contains(file_content, routes_to_inject, fn content ->
      inject_before_final_end(content, routes_to_inject)
    end)
  end

  @doc """
  Injects route blocks after a specific live_session anchor in the router.

  Searches for `live_session :authenticated` or similar patterns and injects
  routes inside the existing live_session block.
  """
  def inject_into_live_session(file_content, session_name, routes_to_inject) do
    inject_unless_contains(file_content, routes_to_inject, fn content ->
      # Find the live_session block and inject before its closing `end`
      pattern = ~r/(live_session\s+:#{session_name}.*?do\n)(.*?)((\s+)end\s*\n\s*end)/s

      case Regex.run(pattern, content, return: :index) do
        nil ->
          nil

        [{full_start, full_len} | _] ->
          # Find the last `end` before the outer scope end to inject before it
          full_match = binary_part(content, full_start, full_len)

          case String.split(full_match, "\n") do
            lines when length(lines) > 2 ->
              # Insert routes before the last `end` line of the live_session
              indent = "      "
              indented_routes = indent_code(routes_to_inject, indent)

              # Use regex to inject before the closing end of the live_session
              new_content =
                Regex.replace(
                  ~r/(live_session\s+:#{session_name}.*?do\n)(.*?)(\s+end\s*\n\s*end)/s,
                  content,
                  "\\1\\2\n#{indented_routes}\n\\3",
                  global: false
                )

              if new_content != content, do: new_content, else: nil

            _ ->
              nil
          end
      end
    end)
  end

  @doc """
  Injects fields into an existing Scope struct's defstruct call.

  Finds `defstruct` in the Scope module and adds new fields.
  """
  def inject_scope_fields(file_content, fields_to_inject) do
    inject_unless_contains(file_content, fields_to_inject, fn content ->
      case Regex.run(~r/(defstruct\s+)(.*?)(\n\n)/s, content) do
        [_full, prefix, existing_fields, suffix] ->
          new_fields = existing_fields <> ",\n" <> fields_to_inject

          String.replace(
            content,
            prefix <> existing_fields <> suffix,
            prefix <> new_fields <> suffix, global: false)

        nil ->
          nil
      end
    end)
  end

  @doc """
  Injects a child spec into the Application supervision tree.

  Finds the `children = [` list and adds the new child.
  """
  def inject_supervision_child(file_content, child_to_inject) do
    inject_unless_contains(file_content, child_to_inject, fn content ->
      # Find the children list and inject before the endpoint
      pattern = ~r/(children\s*=\s*\[)(.*?)(#{Regex.escape("Web.Endpoint")})/s

      case Regex.run(pattern, content) do
        [full, prefix, existing, endpoint] ->
          new_content = prefix <> existing <> child_to_inject <> ",\n      " <> endpoint
          String.replace(content, full, new_content, global: false)

        nil ->
          nil
      end
    end)
  end

  @doc """
  Prints instructions for deps to add to mix.exs.
  """
  def inject_deps_instructions(deps) do
    Mix.shell().info("""

    Add the following dependencies to your mix.exs:

        defp deps do
          [
            ...
    #{Enum.map_join(deps, "\n", fn dep -> "        #{dep}," end)}
          ]
        end

    Then run:

        $ mix deps.get
    """)
  end

  @doc """
  Injects code into a file if not already present.

  Reads the file, checks if the marker is already present,
  and if not, calls the injection function and writes the result.
  Returns `:ok` on success, `:already_injected`, or raises on error.
  """
  def inject_into_file(file_path, code_to_inject, injection_fn) do
    content = File.read!(file_path)

    case inject_unless_contains(content, code_to_inject, injection_fn) do
      {:ok, new_content} ->
        File.write!(file_path, new_content)
        :ok

      :already_injected ->
        :already_injected

      {:error, :unable_to_inject} ->
        Mix.shell().error("""
        Could not automatically inject into #{file_path}.
        Please add the following manually:

        #{code_to_inject}
        """)

        {:error, :unable_to_inject}
    end
  end

  @doc """
  Injects code before the final `end` in the content.
  """
  def inject_before_final_end(content, code_to_inject) do
    case String.trim_trailing(content) |> String.ends_with?("end") do
      true ->
        trimmed = String.trim_trailing(content)
        # Find the last `end`
        {before, _last_end} = String.split_at(trimmed, String.length(trimmed) - 3)
        before <> "\n" <> code_to_inject <> "\nend\n"

      false ->
        nil
    end
  end

  # Private helpers

  defp inject_unless_contains(content, marker, injection_fn) do
    # Normalize for comparison - strip excess whitespace
    normalized_marker = String.trim(marker)
    normalized_content = String.trim(content)

    if String.contains?(normalized_content, normalized_marker) do
      :already_injected
    else
      case injection_fn.(content) do
        nil -> {:error, :unable_to_inject}
        new_content when is_binary(new_content) -> {:ok, new_content}
      end
    end
  end

  defp indent_code(code, indent) do
    code
    |> String.split("\n")
    |> Enum.map_join("\n", fn
      "" -> ""
      line -> indent <> line
    end)
  end
end
