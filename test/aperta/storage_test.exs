defmodule Aperta.StorageTest do
  # Integration tests against a real S3-compatible backend (MinIO locally).
  # Each test uses a unique key so parallel runs don't collide.
  use ExUnit.Case, async: true

  @moduletag :storage

  alias Aperta.Storage

  setup do
    key = "test/#{Ecto.UUID.generate()}"
    on_exit(fn -> Storage.delete(key) end)
    {:ok, key: key}
  end

  test "put/get/delete roundtrip with a binary body", %{key: key} do
    assert :ok = Storage.put(key, "hello world", content_type: "text/plain")
    assert {:ok, "hello world"} = Storage.get(key)

    assert :ok = Storage.delete(key)
    assert {:error, _} = Storage.get(key)
  end

  test "put accepts a file path and uploads its contents", %{key: key} do
    path =
      Path.join(System.tmp_dir!(), "aperta-storage-#{System.unique_integer([:positive])}.bin")

    bytes = :crypto.strong_rand_bytes(4096)
    File.write!(path, bytes)
    on_exit(fn -> File.rm(path) end)

    assert :ok = Storage.put(key, {:file, path}, content_type: "application/pdf")
    assert {:ok, ^bytes} = Storage.get(key)
  end

  test "presigned_get_url returns a URL that actually serves the object", %{key: key} do
    assert :ok = Storage.put(key, "presigned payload", content_type: "text/plain")

    assert {:ok, url} = Storage.presigned_get_url(key, expires_in: 60)
    assert String.starts_with?(url, "http://localhost:9000/aperta-documents/")

    # Prove the URL works — Req is already a dep and the rule says to use it.
    assert %Req.Response{status: 200, body: "presigned payload"} = Req.get!(url)
  end

  test "get returns an error for missing keys" do
    assert {:error, _} = Storage.get("test/definitely-missing-#{Ecto.UUID.generate()}")
  end
end
