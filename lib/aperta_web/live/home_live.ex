defmodule ApertaWeb.HomeLive do
  @moduledoc """
  Public landing page.

  Pitches Aperta to first-time visitors and routes them into the app —
  authenticated users get a "Go to library" CTA, everyone else gets
  sign-up + log-in.
  """
  use ApertaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Aperta — your PDF library, everywhere")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="relative isolate overflow-hidden rounded-2xl border border-base-200 bg-base-100 px-6 py-16 sm:px-10 sm:py-24">
        <div class="pointer-events-none absolute inset-0 -z-10 opacity-40">
          <div class="absolute left-1/2 top-0 h-[28rem] w-[28rem] -translate-x-1/2 rounded-full bg-primary/20 blur-3xl" />
          <div class="absolute right-0 bottom-0 h-[20rem] w-[20rem] translate-x-1/3 translate-y-1/3 rounded-full bg-accent/20 blur-3xl" />
        </div>

        <div class="mx-auto max-w-3xl text-center space-y-6">
          <p class="inline-flex items-center gap-2 rounded-full border border-base-300 bg-base-200/70 px-3 py-1 text-xs font-medium uppercase tracking-wide text-base-content/70">
            <.icon name="hero-sparkles" class="size-4" /> Reading, picked up wherever you left off
          </p>

          <h1 class="text-balance text-4xl font-semibold tracking-tight sm:text-5xl">
            Your PDF library, synced across every device.
          </h1>

          <p class="mx-auto max-w-2xl text-pretty text-base text-base-content/70 sm:text-lg">
            Aperta stores your PDFs in one place and keeps your reading position
            in sync — start a chapter on your laptop, finish it on your phone.
            No tabs to juggle, no pages to remember.
          </p>

          <div class="flex flex-col items-center justify-center gap-3 pt-2 sm:flex-row">
            <%= if @current_scope do %>
              <.link navigate={~p"/library"} class="btn btn-primary btn-lg gap-2">
                Go to your library <.icon name="hero-arrow-right" class="size-4" />
              </.link>
            <% else %>
              <.link navigate={~p"/users/register"} class="btn btn-primary btn-lg gap-2">
                Create an account <.icon name="hero-arrow-right" class="size-4" />
              </.link>
              <.link navigate={~p"/users/log-in"} class="btn btn-ghost btn-lg">
                I already have an account
              </.link>
            <% end %>
          </div>
        </div>
      </section>

      <section class="mt-10 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <.feature
          icon="hero-cloud-arrow-up"
          title="Upload anything"
          body="Drag-and-drop any PDF, from research papers to novels. We store the originals, untouched."
        />
        <.feature
          icon="hero-arrow-path-rounded-square"
          title="Page sync"
          body="Your current page follows you between browsers and devices, in real time."
        />
        <.feature
          icon="hero-lock-closed"
          title="Your shelf only"
          body="Every account gets its own isolated library. No sharing, no crossed wires."
        />
      </section>
    </Layouts.app>
    """
  end

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :body, :string, required: true

  defp feature(assigns) do
    ~H"""
    <div class="rounded-xl border border-base-200 bg-base-100 p-5 transition hover:border-primary/40 hover:bg-base-200/40">
      <div class="mb-3 inline-flex size-10 items-center justify-center rounded-lg bg-primary/10 text-primary">
        <.icon name={@icon} class="size-5" />
      </div>
      <h3 class="text-base font-semibold">{@title}</h3>
      <p class="mt-1 text-sm text-base-content/70">{@body}</p>
    </div>
    """
  end
end
