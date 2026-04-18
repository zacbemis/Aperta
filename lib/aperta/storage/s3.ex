defmodule Aperta.Storage.S3 do
  @moduledoc """
  S3-backed `Aperta.Storage` implementation.

  Works with any S3-compatible service — we use MinIO in dev/test and real
  Amazon S3 (or any compatible provider) in prod. Connection details come from
  `:ex_aws` / `:ex_aws, :s3` config.
  """

  @behaviour Aperta.Storage

  alias Aperta.Storage

  @impl Aperta.Storage
  def put(key, {:file, path}, opts) when is_binary(path) do
    # For v1 we read the file once and send it as a single PUT. This is fine
    # for typical PDFs; switch to `ExAws.S3.Upload` / multipart when we start
    # routinely seeing files in the hundreds of megabytes.
    path
    |> File.read!()
    |> do_put(key, opts)
  end

  def put(key, body, opts) when is_binary(body) do
    do_put(body, key, opts)
  end

  @impl Aperta.Storage
  def get(key) do
    case Storage.bucket() |> ExAws.S3.get_object(key) |> ExAws.request() do
      {:ok, %{body: body}} -> {:ok, body}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Aperta.Storage
  def delete(key) do
    case Storage.bucket() |> ExAws.S3.delete_object(key) |> ExAws.request() do
      {:ok, _resp} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Aperta.Storage
  def presigned_get_url(key, opts) do
    expires_in = Keyword.get(opts, :expires_in, 3600)
    config = ExAws.Config.new(:s3)

    ExAws.S3.presigned_url(config, :get, Storage.bucket(), key, expires_in: expires_in)
  end

  defp do_put(body, key, opts) do
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")

    result =
      Storage.bucket()
      |> ExAws.S3.put_object(key, body, content_type: content_type)
      |> ExAws.request()

    case result do
      {:ok, _resp} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
