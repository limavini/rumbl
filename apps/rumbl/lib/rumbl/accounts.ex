defmodule Rumbl.Accounts do
  @moduledoc """
    The Accounts context.
  """
  import Ecto.Query
  alias Rumbl.Accounts.User
  alias Rumbl.Repo

  def list_users, do: Repo.all(User)

  def list_users_with_ids(ids) do
    Repo.all(from(u in User, where: u.id in ^ids))
  end

  def get_user(id), do: Repo.get(User, id)

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by(params), do: Repo.get_by(User, params)

  def change_user(%User{} = user), do: User.changeset(user, %{})

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def change_registration(%User{} = user, params) do
    User.registration_changeset(user, params)
  end

  def register_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def authenticate_by_username_and_pass(username, given_pass) do
    # Get user if exists
    user = get_user_by(username: username)

    cond do
      # Check if given pass matches the one on database
      user && Pbkdf2.verify_pass(given_pass, user.password_hash) ->
        {:ok, user}

      user ->
        {:error, :unauthorized}

      # If user does not exists, simulate password checking
      true ->
        Pbkdf2.no_user_verify()
        {:error, :not_found}
    end
  end
end
