defmodule Mix.Tasks.Aperta.Vendor.Pdfjs do
  @shortdoc "Downloads and vendors the prebuilt PDF.js viewer"

  @moduledoc """
  Downloads Mozilla's prebuilt PDF.js viewer from GitHub releases and
  extracts it into `priv/static/vendor/pdfjs/`.

  We use the release zip (rather than the `pdfjs-dist` npm package) because
  npm only ships the PDFViewer *component library* — the full prebuilt
  viewer (`web/viewer.html` + toolbar, sidebar, keyboard shortcuts, etc.)
  lives in `pdfjs-<version>-dist.zip` on GitHub releases.

  Also installs the small `aperta-bridge.js` integration script (sourced
  from `assets/vendor/pdfjs-bridge.js`) and wires it into `viewer.html`,
  which is what lets `ApertaWeb.ReaderLive` talk to the viewer via
  `postMessage`.

  The zip is cached under `_build/pdfjs-cache/` so repeated runs are cheap.
  Bump `@version` here when we're ready to track a new PDF.js release.

  Normally invoked via `mix assets.setup`. Run it manually after pulling
  fresh or whenever the `priv/static/vendor/pdfjs/` directory goes missing.
  """

  use Mix.Task

  @version "4.10.38"
  @url "https://github.com/mozilla/pdf.js/releases/download/v#{@version}/pdfjs-#{@version}-dist.zip"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.config")
    {:ok, _} = Application.ensure_all_started(:req)

    target = Path.expand("priv/static/vendor/pdfjs")
    cache = Path.expand("_build/pdfjs-cache/pdfjs-#{@version}-dist.zip")
    bridge = Path.expand("assets/vendor/pdfjs-bridge.js")

    ensure_zip(cache)
    replace_target(target, cache)
    install_bridge(target, bridge)

    Mix.shell().info("Vendored PDF.js v#{@version} to #{target}")
  end

  defp ensure_zip(cache) do
    if File.regular?(cache) do
      :ok
    else
      Mix.shell().info("Downloading PDF.js v#{@version}...")
      File.mkdir_p!(Path.dirname(cache))

      case Req.get(@url, redirect: true, decode_body: false, receive_timeout: 60_000) do
        {:ok, %{status: 200, body: body}} when is_binary(body) ->
          File.write!(cache, body)

        {:ok, %{status: status}} ->
          Mix.raise("Failed to download #{@url}: HTTP #{status}")

        {:error, reason} ->
          Mix.raise("Failed to download #{@url}: #{inspect(reason)}")
      end
    end
  end

  defp replace_target(target, cache) do
    File.rm_rf!(target)
    File.mkdir_p!(target)

    {:ok, _files} =
      :zip.unzip(String.to_charlist(cache), cwd: String.to_charlist(target))

    :ok
  end

  defp install_bridge(target, bridge) do
    if File.regular?(bridge) do
      dest = Path.join([target, "web", "aperta-bridge.js"])
      File.cp!(bridge, dest)
      inject_bridge(Path.join([target, "web", "viewer.html"]))
    else
      Mix.shell().info("[warn] #{bridge} missing — skipping bridge injection")
    end
  end

  defp inject_bridge(viewer_html) do
    case File.read(viewer_html) do
      {:ok, content} ->
        if String.contains?(content, "aperta-bridge.js") do
          :ok
        else
          tag = ~s(    <script src="aperta-bridge.js"></script>\n  </body>)
          patched = String.replace(content, "</body>", tag, global: false)
          File.write!(viewer_html, patched)
        end

      {:error, reason} ->
        Mix.shell().info(
          "[warn] could not read #{viewer_html}: #{inspect(reason)} — bridge not injected"
        )
    end
  end
end
