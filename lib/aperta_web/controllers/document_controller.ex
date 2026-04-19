defmodule ApertaWeb.DocumentController do
  @moduledoc """
  Serves document bytes to the browser.

  Proxies the blob through Phoenix (instead of handing the browser a
  presigned MinIO/S3 URL) so the vendored PDF.js viewer sees a same-origin
  `?file=` parameter — its `validateFileURL` check refuses cross-origin
  URLs.

  The controller is a streaming pass-through: it advertises
  `Accept-Ranges: bytes` and forwards any `Range` header straight to the
  storage backend via `Aperta.Storage.stream/2`. The upstream response body
  is an enumerable of chunks that we pipe into `Plug.Conn.chunk/2`, so
  server memory stays O(one chunk) no matter how large the PDF is.

  That lets PDF.js lazy-load only the pages the user actually visits: the
  viewer sends `Range: bytes=X-Y` for each page window, we return `206
  Partial Content` with a matching `Content-Range`, and never buffer the
  full file.
  """

  use ApertaWeb, :controller

  alias Aperta.Documents.Document
  alias Aperta.Library
  alias Aperta.Storage

  def show(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope
    document = Library.get_document!(scope, id)

    case parse_range(conn, document) do
      {:ok, :full} ->
        proxy(conn, document, _range = nil)

      {:ok, {start_byte, end_byte}} ->
        proxy(conn, document, {start_byte, end_byte})

      :unsatisfiable ->
        conn
        |> put_resp_header("content-range", "bytes */#{document.byte_size}")
        |> send_resp(:requested_range_not_satisfiable, "")
    end
  end

  defp proxy(conn, %Document{} = document, range) do
    stream_opts =
      case range do
        nil -> []
        {s, e} -> [range: "bytes=#{s}-#{e}"]
      end

    case Storage.stream(document.storage_key, stream_opts) do
      {:ok, %{status: upstream_status, body: body}} when upstream_status in [200, 206] ->
        conn
        |> base_headers(document)
        |> put_range_headers(document, range)
        |> send_chunked(response_status(upstream_status, range))
        |> relay(body)

      _ ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(:bad_gateway, "Unable to load document.")
    end
  end

  defp base_headers(conn, %Document{} = document) do
    conn
    |> put_resp_header("content-type", document.content_type)
    |> put_resp_header("accept-ranges", "bytes")
    |> put_resp_header(
      "content-disposition",
      ~s|inline; filename="#{document.filename}"|
    )
    |> put_resp_header("cache-control", "private, max-age=0, no-store")
  end

  defp put_range_headers(conn, %Document{byte_size: total}, {s, e}) do
    conn
    |> put_resp_header("content-length", Integer.to_string(e - s + 1))
    |> put_resp_header("content-range", "bytes #{s}-#{e}/#{total}")
  end

  defp put_range_headers(conn, %Document{byte_size: total}, nil) do
    put_resp_header(conn, "content-length", Integer.to_string(total))
  end

  defp response_status(_upstream, {_, _}), do: 206
  defp response_status(upstream, nil), do: upstream

  defp relay(conn, body_stream) do
    Enum.reduce_while(body_stream, conn, fn chunk, conn ->
      case Plug.Conn.chunk(conn, chunk) do
        {:ok, new_conn} -> {:cont, new_conn}
        {:error, _reason} -> {:halt, conn}
      end
    end)
  end

  # Returns `{:ok, :full}` when no Range was requested, `{:ok, {s, e}}`
  # when the Range is valid, or `:unsatisfiable` when the Range is
  # malformed / out of bounds (RFC 7233 §4.4).
  defp parse_range(conn, %Document{byte_size: size}) do
    case get_req_header(conn, "range") do
      [] ->
        {:ok, :full}

      [header | _] ->
        parse_range_header(header, size)
    end
  end

  defp parse_range_header("bytes=" <> spec, size) do
    case String.split(spec, ",", parts: 2) do
      # We intentionally don't support multi-range requests in v1 —
      # PDF.js never asks for them and they'd require a multipart body.
      [single] -> parse_single_range(single, size)
      _ -> :unsatisfiable
    end
  end

  defp parse_range_header(_, _), do: :unsatisfiable

  defp parse_single_range(spec, size) do
    case String.split(spec, "-", parts: 2) do
      [start_str, ""] ->
        with {start_byte, ""} <- Integer.parse(start_str),
             true <- start_byte >= 0 and start_byte < size do
          {:ok, {start_byte, size - 1}}
        else
          _ -> :unsatisfiable
        end

      ["", suffix_str] ->
        # "bytes=-N" = last N bytes
        with {suffix, ""} <- Integer.parse(suffix_str),
             true <- suffix > 0 do
          start_byte = max(size - suffix, 0)
          {:ok, {start_byte, size - 1}}
        else
          _ -> :unsatisfiable
        end

      [start_str, end_str] ->
        with {start_byte, ""} <- Integer.parse(start_str),
             {end_byte, ""} <- Integer.parse(end_str),
             true <- start_byte <= end_byte and start_byte < size do
          {:ok, {start_byte, min(end_byte, size - 1)}}
        else
          _ -> :unsatisfiable
        end

      _ ->
        :unsatisfiable
    end
  end
end
