defmodule RumblWeb.VideoChannel do
  use RumblWeb, :channel
  alias Rumbl.{Accounts, Multimedia}
  alias RumblWeb.AnnotationView

  # socket.assigns has socket state

  def join("videos:" <> video_id, params, socket) do
    send(self(), :after_join)
    last_seen_id = params["last_seen_id"] || 0

    annotations =
      video_id
      |> String.to_integer()
      |> Multimedia.get_video!()
      |> Multimedia.list_anottations(last_seen_id)
      |> Phoenix.View.render_many(AnnotationView, "annotation.json")

    {:ok, %{annotations: annotations}, assign(socket, :video_id, String.to_integer(video_id))}
  end

  def handle_in(event, params, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)
    handle_in(event, params, user, socket)
  end

  def handle_info(:after_join, socket) do
    push(socket, "presence_state", RumblWeb.Presence.list(socket))

    {:ok, _} =
      RumblWeb.Presence.track(
        socket,
        socket.assigns.user_id,
        %{device: "browser"}
      )

    {:noreply, socket}
  end

  # handle in -> receives direct channel events
  # handle_out -> intercepts broadcast events
  # handle_info -> receives OTP messages

  def handle_in("new_annotation", params, user, socket) do
    case Multimedia.annotate_video(user, socket.assigns.video_id, params) do
      {:ok, annotation} ->
        broadcast_annotation(socket, user, annotation)
        Task.start(fn -> compute_additional_info(annotation, socket) end)
        {:reply, :ok, socket}

      {:error, changeset} ->
        {:reply, {:error, %{errors: changeset}}, socket}
    end
  end

  defp broadcast_annotation(socket, user, annotation) do
    broadcast!(socket, "new_annotation", %{
      id: annotation.id,
      user: RumblWeb.UserView.render("user.json", %{user: user}),
      body: annotation.body,
      at: annotation.at
    })

    {:reply, :ok, socket}
  end

  defp compute_additional_info(annotation, socket) do
    IO.puts("compute additional info")

    for result <-
          InfoSys.compute(annotation.body, limit: 1, timeout: 10_000) do
      IO.inspect(result)
      backend_user = Accounts.get_user_by(username: result.backend.name())
      attrs = %{body: result.text, at: annotation.at}
      IO.puts("AFTER RESULT...")
      IO.inspect(result)

      case Multimedia.annotate_video(
             backend_user,
             annotation.video_id,
             attrs
           ) do
        {:ok, info_ann} -> broadcast_annotation(socket, backend_user, info_ann)
        {:error, _changeset} -> :ignore
      end
    end
  end
end
