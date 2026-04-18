defmodule ApertaWeb.Router do
  use ApertaWeb, :router

  import ApertaWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ApertaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Other scopes may use custom stacks.
  # scope "/api", ApertaWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:aperta, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ApertaWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", ApertaWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{ApertaWeb.UserAuth, :require_authenticated}] do
      live "/library", LibraryLive, :index
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", ApertaWeb do
    pipe_through [:browser]

    # Public surface + auth entry points. The landing page and magic-link
    # flows are fine for both anonymous and logged-in visitors, so they
    # live under the same :current_user live_session as the rest of the
    # generator output.
    live_session :current_user,
      on_mount: [{ApertaWeb.UserAuth, :mount_current_scope}] do
      live "/", HomeLive, :index
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    # Registration is open, but already-authenticated users should never
    # see the form — bounce them to the library instead.
    live_session :redirect_if_authenticated,
      on_mount: [{ApertaWeb.UserAuth, :redirect_if_authenticated}] do
      live "/users/register", UserLive.Registration, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
