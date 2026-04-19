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
  @type stream_opts :: [range: String.t()]
  @type stream_response :: %{
          required(:status) => non_neg_integer(),
          required(:headers) => map(),
          required(:body) => Enumerable.t()
        }

  @callback put(key, source, put_opts) :: :ok | {:error, term()}
  @callback get(key) :: {:ok, binary()} | {:error, term()}
  @callback delete(key) :: :ok | {:error, term()}
  @callback presigned_get_url(key, presign_opts) ::
              {:ok, String.t()} | {:error, term()}
  @callback stream(key, stream_opts) :: {:ok, stream_response} | {:error, term()}

  @spec put(key, source, put_opts) :: :ok | {:error, term()}
  def put(key, source, opts \\ []), do: backend().put(key, source, opts)

  @spec get(key) :: {:ok, binary()} | {:error, term()}
  def get(key), do: backend().get(key)

  @spec delete(key) :: :ok | {:error, term()}
  def delete(key), do: backend().delete(key)

  @spec presigned_get_url(key, presign_opts) :: {:ok, String.t()} | {:error, term()}
  def presigned_get_url(key, opts \\ []), do: backend().presigned_get_url(key, opts)

  @doc """
  Streams a stored object from the backend.

  On success returns `{:ok, %{status: _, headers: _, body: enumerable}}` — the
  `body` is enumerable chunk-by-chunk so callers (typically
  `ApertaWeb.DocumentController`) can pipe it straight into
  `Plug.Conn.chunk/2` without ever holding the whole blob in memory.

  Pass `:range` to forward an HTTP Range header; the backend propagates it
  upstream so the resulting `status` may be `206` and the response
  `headers` will carry `content-range` / `content-length`.
  """
  @spec stream(key, stream_opts) :: {:ok, stream_response} | {:error, term()}
  def stream(key, opts \\ []), do: backend().stream(key, opts)

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
