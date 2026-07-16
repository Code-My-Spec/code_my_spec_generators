defmodule <%= app_module %>.Content.Pull do
  @moduledoc """
  Executes a content pull: fetch the manifest, parse + validate its fields,
  fetch the content blob, verify its sha256 against the manifest hash, and
  atomically replace local content.

  Integrity is all-or-nothing: a malformed manifest or a hash mismatch aborts
  the sync without touching existing content. The atomic replace is delegated
  to `<%= app_module %>.Content.sync_content/1` (a single transaction).
  """

  require Logger

  alias <%= app_module %>.Content
  alias <%= app_module %>.Content.PullClient

  @required_fields ~w(version generated_at content_blob_url content_blob_hash counts)
  @supported_version "1.0"

  @doc """
  Run a pull from `manifest_url`. Returns `:ok` on a clean sync, `{:error,
  reason}` on any failure (existing content left intact).
  """
  @spec run(String.t()) :: :ok | {:error, term()}
  def run(manifest_url) do
    with {:ok, manifest_bytes} <- PullClient.fetch(manifest_url),
         {:ok, manifest} <- parse_manifest(manifest_bytes),
         {:ok, blob_bytes} <- PullClient.fetch(manifest["content_blob_url"]),
         :ok <- verify_hash(blob_bytes, manifest["content_blob_hash"]),
         {:ok, rows} <- decode_blob(blob_bytes),
         {:ok, _records} <- persist(rows) do
      :ok
    else
      {:error, reason} = error ->
        Logger.warning("[Content.Pull] aborted: #{inspect(reason)}")
        error
    end
  end

  defp parse_manifest(bytes) do
    case Jason.decode(bytes) do
      {:ok, manifest} when is_map(manifest) ->
        cond do
          not Enum.all?(@required_fields, &Map.has_key?(manifest, &1)) ->
            {:error, :malformed_manifest}

          manifest["version"] != @supported_version ->
            {:error, :wrong_version}

          true ->
            {:ok, manifest}
        end

      _ ->
        {:error, :malformed_manifest}
    end
  end

  defp verify_hash(bytes, "sha256:" <> expected_hex) do
    actual = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
    if Plug.Crypto.secure_compare(actual, expected_hex), do: :ok, else: {:error, :hash_mismatch}
  end

  defp verify_hash(_bytes, _other), do: {:error, :bad_hash_format}

  defp decode_blob(bytes) do
    case Jason.decode(bytes) do
      {:ok, rows} when is_list(rows) -> {:ok, rows}
      _ -> {:error, :malformed_blob}
    end
  end

  defp persist(rows) do
    case Content.sync_content(rows) do
      {:ok, records} ->
        sync_tags(records, rows)
        {:ok, records}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # sync_content inserts in list order, so records line up with rows.
  defp sync_tags(records, rows) do
    records
    |> Enum.zip(rows)
    |> Enum.each(fn {record, row} ->
      case row["tags"] do
        tags when is_list(tags) and tags != [] -> Content.sync_content_tags(record, tags)
        _ -> :ok
      end
    end)
  end
end
