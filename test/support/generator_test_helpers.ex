defmodule CodeMySpecGenerators.GeneratorTestHelpers do
  @moduledoc """
  Test helpers for generator tests.

  Provides utilities for creating temporary Phoenix apps, running generators,
  compiling the output, and verifying generated files.
  """

  @doc """
  Creates a temporary directory for test output.
  Returns the path to the temp directory.
  """
  def create_tmp_dir(prefix \\ "cms_gen_test") do
    tmp_dir = Path.join(System.tmp_dir!(), "#{prefix}_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    tmp_dir
  end

  @doc """
  Cleans up a temporary directory.
  """
  def cleanup_tmp_dir(tmp_dir) do
    File.rm_rf!(tmp_dir)
  end

  @doc """
  Asserts that a file exists at the given path.
  """
  def assert_file(path) do
    assert File.exists?(path), "Expected file #{path} to exist"
  end

  def assert_file(path, match) when is_binary(match) do
    assert_file(path)
    content = File.read!(path)

    assert String.contains?(content, match),
           "Expected file #{path} to contain #{inspect(match)}, but it contained:\n#{content}"
  end

  def assert_file(path, matches) when is_list(matches) do
    assert_file(path)
    content = File.read!(path)

    Enum.each(matches, fn match ->
      assert String.contains?(content, match),
             "Expected file #{path} to contain #{inspect(match)}"
    end)
  end

  def assert_file(path, fun) when is_function(fun, 1) do
    assert_file(path)
    content = File.read!(path)
    fun.(content)
  end

  @doc """
  Asserts that a file does NOT exist at the given path.
  """
  def refute_file(path) do
    refute File.exists?(path), "Expected file #{path} to not exist"
  end

  defp assert(true, _message), do: :ok
  defp assert(false, message), do: raise(message)
  defp refute(false, _message), do: :ok
  defp refute(true, message), do: raise(message)
end
