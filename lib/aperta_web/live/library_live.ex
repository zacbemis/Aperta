defmodule ApertaWeb.LibraryLive do
  use ApertaWeb, :live_view

  alias Aperta.Documents.Document
  alias Aperta.Library
  alias Aperta.Storage

  # 500 MB — cap picked in the v1 plan. Revisit if real-world PDFs start to
  # bump up against it.
  @max_file_size 500_000_000

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    socket =
      socket
      |> assign(:page_title, "Your library")
      |> stream(:documents, Library.list_documents(scope))
      |> allow_upload(:pdf,
        accept: ~w(.pdf application/pdf),
        max_entries: 10,
        max_file_size: @max_file_size
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Your library
        <:subtitle>Every PDF you upload lives here, synced across your devices.</:subtitle>
      </.header>

      <form id="upload-form" phx-submit="save" phx-change="validate">
        <label
          class={[
            "flex flex-col items-center justify-center gap-2 rounded-lg border-2 border-dashed",
            "border-base-300 bg-base-200/40 px-6 py-12 text-center cursor-pointer transition",
            "hover:border-primary hover:bg-base-200"
          ]}
          phx-drop-target={@uploads.pdf.ref}
        >
          <.live_file_input upload={@uploads.pdf} class="sr-only" />
          <.icon name="hero-arrow-up-tray" class="size-8 opacity-70" />
          <p class="text-sm">
            <span class="font-medium">Drop PDFs here</span>
            <span class="opacity-70">— or click to browse</span>
          </p>
          <p class="text-xs opacity-60">Up to 500 MB per file, 10 at a time.</p>
        </label>

        <div :if={@uploads.pdf.entries != []} class="mt-4 space-y-2">
          <div
            :for={entry <- @uploads.pdf.entries}
            id={"upload-entry-#{entry.ref}"}
            class="flex items-center gap-3 rounded border border-base-300 bg-base-100 px-3 py-2"
          >
            <.icon name="hero-document" class="size-4 opacity-60 shrink-0" />
            <span class="flex-1 truncate text-sm">{entry.client_name}</span>
            <progress value={entry.progress} max="100" class="progress progress-primary w-32" />
            <button
              type="button"
              phx-click="cancel"
              phx-value-ref={entry.ref}
              aria-label="Cancel upload"
              class="opacity-60 hover:opacity-100"
            >
              <.icon name="hero-x-mark" class="size-4" />
            </button>
          </div>

          <p
            :for={err <- upload_errors(@uploads.pdf)}
            class="text-sm text-error"
          >
            {error_to_string(err)}
          </p>
        </div>

        <div class="mt-4 flex justify-end">
          <.button type="submit" disabled={@uploads.pdf.entries == []} class="btn btn-primary">
            Upload
          </.button>
        </div>
      </form>

      <section class="mt-10">
        <h2 class="text-lg font-semibold mb-4">Documents</h2>
        <div
          id="documents"
          phx-update="stream"
          class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3"
        >
          <div
            id="documents-empty"
            class="hidden only:block rounded-lg border border-dashed border-base-300 p-8 text-center text-sm opacity-60 col-span-full"
          >
            No documents yet. Drop a PDF above to get started.
          </div>
          <article
            :for={{dom_id, doc} <- @streams.documents}
            id={dom_id}
            class="rounded-lg border border-base-300 bg-base-100 hover:border-primary transition"
          >
            <.link navigate={~p"/library/#{doc.id}"} class="block p-4">
              <p class="font-medium truncate">{doc.title}</p>
              <p :if={doc.author} class="text-sm opacity-75 truncate">{doc.author}</p>
              <p class="text-xs opacity-60 mt-2 truncate">
                {doc.filename}{page_count_suffix(doc)}
              </p>
            </.link>
          </article>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("cancel", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :pdf, ref)}
  end

  def handle_event("save", _params, socket) do
    scope = socket.assigns.current_scope

    results =
      consume_uploaded_entries(socket, :pdf, fn %{path: path}, entry ->
        case upload_and_create(scope, path, entry) do
          {:ok, %Document{} = doc} -> {:ok, doc}
          {:error, reason} -> {:ok, {:error, reason}}
        end
      end)

    {docs, errors} =
      Enum.split_with(results, fn
        %Document{} -> true
        _ -> false
      end)

    socket =
      Enum.reduce(docs, socket, fn doc, acc ->
        stream_insert(acc, :documents, doc, at: 0)
      end)

    socket =
      cond do
        errors != [] and docs != [] ->
          put_flash(
            socket,
            :error,
            "Uploaded #{length(docs)} document(s); #{length(errors)} failed."
          )

        errors != [] ->
          put_flash(socket, :error, "Upload failed. See logs for details.")

        docs != [] ->
          put_flash(socket, :info, "Uploaded #{length(docs)} document(s).")

        true ->
          socket
      end

    {:noreply, socket}
  end

  defp upload_and_create(scope, path, entry) do
    key = storage_key(scope)
    content_type = entry.client_type || "application/pdf"

    with :ok <- Storage.put(key, {:file, path}, content_type: content_type),
         {:ok, %Document{} = doc} <- create_document(scope, entry, key, content_type) do
      {:ok, doc}
    else
      {:error, _reason} = err ->
        # Best-effort cleanup so we don't leak orphan objects in MinIO.
        _ = Storage.delete(key)
        err
    end
  end

  defp create_document(scope, entry, key, content_type) do
    Library.create_document(scope, %{
      format: "pdf",
      title: Path.rootname(entry.client_name),
      filename: entry.client_name,
      content_type: content_type,
      byte_size: entry.client_size,
      storage_key: key
    })
  end

  defp storage_key(scope) do
    "documents/#{scope.user.id}/#{Ecto.UUID.generate()}.pdf"
  end

  defp page_count_suffix(%Document{page_count: nil}), do: ""
  defp page_count_suffix(%Document{page_count: n}), do: " · #{n} pages"

  defp error_to_string(:too_large), do: "One of the files is larger than 500 MB."
  defp error_to_string(:not_accepted), do: "Only PDF files can be uploaded."
  defp error_to_string(:too_many_files), do: "You can upload at most 10 files at a time."
  defp error_to_string(other), do: "Upload error: #{inspect(other)}."
end
