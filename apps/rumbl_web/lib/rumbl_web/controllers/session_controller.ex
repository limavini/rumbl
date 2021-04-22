defmodule RumblWeb.SessionController do
  use RumblWeb, :controller

  def new(conn, _) do
    conn
    |> render("new.html")
  end

  # Handle login form submission
  def create(conn, %{"session" => %{"username" => username, "password" => pass}}) do
    case Rumbl.Accounts.authenticate_by_username_and_pass(username, pass) do
      # If user exists and user/pass are correct
      {:ok, user} ->
        conn
        |> RumblWeb.Auth.login(user)
        |> put_flash(:info, "Welcome back!")
        |> redirect(to: Routes.page_path(conn, :index))

      # If there's an authentication error
      {:error, _reason} ->
        conn
        |> put_flash(:error, "Invalid username/password combination!")
        |> render("new.html")
    end
  end

  def delete(conn, _) do
    conn
    |> RumblWeb.Auth.logout()
    |> redirect(to: Routes.page_path(conn, :index))
  end
end
