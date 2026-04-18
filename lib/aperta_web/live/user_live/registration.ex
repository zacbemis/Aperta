defmodule ApertaWeb.UserLive.Registration do
  @moduledoc """
  Open registration for Aperta.

  New users register with just an email: we create the `User` row (unconfirmed,
  no password) and deliver a magic-link / confirmation email. Clicking the
  link confirms the account and logs them in; they can then optionally set a
  password on the settings page.

  Already-authenticated users shouldn't see this form — the router's
  `:redirect_if_authenticated` on-mount hook bounces them to `/library`.
  """
  use ApertaWeb, :live_view

  alias Aperta.Accounts
  alias Aperta.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-4">
        <div class="text-center">
          <.header>
            Create your account
            <:subtitle>
              Drop in your email and we'll send a confirmation link. You can
              set a password later on the settings page.
            </:subtitle>
          </.header>
        </div>

        <div :if={local_mail_adapter?()} class="alert alert-info">
          <.icon name="hero-information-circle" class="size-6 shrink-0" />
          <div>
            <p>You're running the local mail adapter.</p>
            <p>
              Confirmation links land in <.link href="/dev/mailbox" class="underline">the dev mailbox</.link>.
            </p>
          </div>
        </div>

        <.form
          for={@form}
          id="registration_form"
          phx-submit="save"
          phx-change="validate"
        >
          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            spellcheck="false"
            required
            phx-mounted={JS.focus()}
          />
          <.button class="btn btn-primary w-full" phx-disable-with="Creating account...">
            Create account <span aria-hidden="true">→</span>
          </.button>
        </.form>

        <p class="text-center text-sm text-base-content/70">
          Already have an account?
          <.link navigate={~p"/users/log-in"} class="link link-primary">
            Log in
          </.link>
        </p>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_email(%User{}, %{}, validate_unique: false)

    {:ok, assign(socket, :form, to_form(changeset, as: "user"))}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, as: "user"))}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    # We don't disclose whether the email is already registered — either way,
    # we say "check your inbox" and send the appropriate email. An existing
    # user gets a magic-link login email; a new user gets a confirmation
    # email.
    email = Map.get(user_params, "email", "")

    case Accounts.get_user_by_email(email) do
      %User{} = existing ->
        Accounts.deliver_login_instructions(
          existing,
          &url(~p"/users/log-in/#{&1}")
        )

        {:noreply, finalize(socket)}

      nil ->
        case Accounts.register_user(user_params) do
          {:ok, user} ->
            Accounts.deliver_login_instructions(
              user,
              &url(~p"/users/log-in/#{&1}")
            )

            {:noreply, finalize(socket)}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset, as: "user"))}
        end
    end
  end

  defp finalize(socket) do
    info =
      "If your email is valid, you'll receive a confirmation link shortly. " <>
        "Click it to finish creating your account."

    socket
    |> put_flash(:info, info)
    |> push_navigate(to: ~p"/users/log-in")
  end

  defp local_mail_adapter? do
    Application.get_env(:aperta, Aperta.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
