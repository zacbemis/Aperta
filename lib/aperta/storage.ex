defmodule Aperta.Storage do
  @moduledoc """
  Blob storage for documents (PDFs today, other formats later).

  Wraps a pluggable backend so the bulk of the app never needs to care whether
  bytes live in MinIO, Amazon S3, a local filesystem, or somewhere else.

  Configure the backend and default bucket in `config/config.exs`:

      config :aperta, Aperta.Storage,
        backend: Aperta.Storage.S3,
        bucket: "aperta-documents"
  """

  @type key :: String.t()
  @type source :: binary() | {:file, Path.t()}
  @type put_opts :: [content_type: String.t()]
  @type presign_opts :: [expires_in: pos_integer()]

  @callback put(key, source, put_opts) :: :ok | {:error, term()}
  @callback get(key) :: {:ok, binary()} | {:error, term()}
  @callback delete(key) :: :ok | {:error, term()}
  @callback presigned_get_url(key, presign_opts) ::
              {:ok, String.t()} | {:error, term()}

  @spec put(key, source, put_opts) :: :ok | {:error, term()}
  def put(key, source, opts \\ []), do: backend().put(key, source, opts)

  @spec get(key) :: {:ok, binary()} | {:error, term()}
  def get(key), do: backend().get(key)

  @spec delete(key) :: :ok | {:error, term()}
  def delete(key), do: backend().delete(key)

  @spec presigned_get_url(key, presign_opts) :: {:ok, String.t()} | {:error, term()}
  def presigned_get_url(key, opts \\ []), do: backend().presigned_get_url(key, opts)

  @doc "Name of the configured bucket."
  @spec bucket() :: String.t()
  def bucket, do: config!(:bucket)

  defp backend, do: config!(:backend)

  defp config!(key) do
    :aperta
    |> Application.fetch_env!(__MODULE__)
    |> Keyword.fetch!(key)
  end
end
