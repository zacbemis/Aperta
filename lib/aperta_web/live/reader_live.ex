defmodule ApertaWeb.ReaderLive do
  @moduledoc """
  Full-screen reader for a single document.

  Hosts the vendored PDF.js viewer (see `mix aperta.vendor.pdfjs`) inside an
  `<iframe>` and bridges its `pagesloaded` / `pagechanging` events through a
  colocated hook. The server persists the reading position through
  `Aperta.Library.update_current_page/3` (last-writer-wins) and fans out
  updates to other devices via `Phoenix.PubSub` on the
  `"document:<id>"` topic.

  Each connected reader tags its broadcasts with a random `origin_id` so a
  device never syncs itself.
  """

  use ApertaWeb, :live_view

  alias Aperta.Documents.Document
  alias Aperta.Library

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    scope = socket.assigns.current_scope
    document = Library.get_document!(scope, id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Aperta.PubSub, topic(document))
    end

    # PDF.js's viewer refuses cross-origin `?file=` URLs ("file origin does
    # not match viewer's"), so we proxy document bytes through our own
    # controller (`ApertaWeb.DocumentController`) instead of handing the
    # browser a presigned MinIO URL.
    file_url = ~p"/library/#{document.id}/file"

    socket =
      socket
      |> assign(:page_title, document.title)
      |> assign(:document, document)
      |> assign(:origin_id, random_origin_id())
      |> assign(
        :viewer_src,
        "/vendor/pdfjs/web/viewer.html?file=" <> URI.encode_www_form(file_url)
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex items-center gap-3">
        <.link navigate={~p"/library"} class="btn btn-ghost btn-sm gap-1">
          <.icon name="hero-arrow-left" class="size-4" /> Library
        </.link>
        <div class="min-w-0 flex-1">
          <h1 class="truncate text-lg font-semibold">{@document.title}</h1>
          <p :if={@document.author} class="truncate text-xs opacity-60">{@document.author}</p>
        </div>
      </div>

      <div
        id={"reader-#{@document.id}"}
        class="mt-4 h-[calc(100vh-10rem)] w-full overflow-hidden rounded-lg border border-base-300"
        phx-update="ignore"
      >
        <iframe
          id="pdf-viewer"
          title={@document.title}
          src={@viewer_src}
          class="h-full w-full"
          phx-hook=".PdfViewer"
          data-origin-id={@origin_id}
        >
        </iframe>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".PdfViewer">
        export default {
          mounted() {
            this.originId = this.el.dataset.originId
            this.debounceTimer = null
            this.lastReportedPage = null
            this.ready = false
            this.pendingPage = null

            this.onMessage = (event) => {
              if (event.source !== this.el.contentWindow) return
              const data = event.data
              if (!data || typeof data.type !== "string") return

              if (data.type === "pdfjs:pagesloaded") {
                this.ready = true
                this.pushEvent("pages_loaded", { num_pages: data.numPages })
                if (this.pendingPage != null) {
                  this.postPage(this.pendingPage)
                  this.pendingPage = null
                }
              } else if (data.type === "pdfjs:pagechanging") {
                const page = data.pageNumber
                if (typeof page !== "number") return
                clearTimeout(this.debounceTimer)
                this.debounceTimer = setTimeout(() => {
                  if (page === this.lastReportedPage) return
                  this.lastReportedPage = page
                  this.pushEvent("page_changed", {
                    page: page,
                    client_updated_at: new Date().toISOString()
                  })
                }, 400)
              }
            }
            window.addEventListener("message", this.onMessage)

            this.handleEvent("sync_to", ({ page }) => {
              this.lastReportedPage = page
              if (this.ready) {
                this.postPage(page)
              } else {
                this.pendingPage = page
              }
            })
          },
          postPage(page) {
            if (!this.el.contentWindow) return
            this.el.contentWindow.postMessage({ type: "pdfjs:set-page", page: page }, "*")
          },
          destroyed() {
            window.removeEventListener("message", this.onMessage)
            clearTimeout(this.debounceTimer)
          }
        }
      </script>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("pages_loaded", %{"num_pages" => num_pages}, socket)
      when is_integer(num_pages) and num_pages > 0 do
    %{document: document, current_scope: scope} = socket.assigns

    document =
      if document.page_count == num_pages do
        document
      else
        case Library.set_page_count(scope, document, num_pages) do
          {:ok, doc} -> doc
          {:error, _} -> document
        end
      end

    socket = assign(socket, :document, document)

    socket =
      if document.current_page > 1 do
        push_event(socket, "sync_to", %{page: document.current_page})
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("pages_loaded", _params, socket), do: {:noreply, socket}

  def handle_event("page_changed", %{"page" => page, "client_updated_at" => ts_str}, socket)
      when is_integer(page) and page >= 1 do
    %{document: document, current_scope: scope, origin_id: origin_id} = socket.assigns

    case DateTime.from_iso8601(ts_str) do
      {:ok, ts, _offset} ->
        {:ok, updated} =
          Library.update_current_page(scope, document, %{page: page, client_updated_at: ts})

        socket = assign(socket, :document, updated)

        socket =
          if accepted?(updated, page, ts) do
            Phoenix.PubSub.broadcast(
              Aperta.PubSub,
              topic(document),
              {:page_updated, updated.current_page, origin_id}
            )

            socket
          else
            # Our write lost the LWW race — snap the viewer to the winner so
            # the user doesn't get stranded on a stale page.
            push_event(socket, "sync_to", %{page: updated.current_page})
          end

        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("page_changed", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:page_updated, page, origin}, socket) do
    if origin == socket.assigns.origin_id do
      {:noreply, socket}
    else
      {:noreply, push_event(socket, "sync_to", %{page: page})}
    end
  end

  defp accepted?(
         %Document{current_page: stored_page, current_page_updated_at: stored_ts},
         page,
         ts
       )
       when not is_nil(stored_ts) do
    stored_page == page and DateTime.compare(stored_ts, ts) == :eq
  end

  defp accepted?(_document, _page, _ts), do: false

  defp topic(%Document{id: id}), do: "document:#{id}"

  defp random_origin_id do
    9 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end
end
