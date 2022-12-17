defmodule Pleroma.Web.Feed.WebSubController do
  use CloudHubWeb, :controller

  alias Pleroma.Feed.Subscriptions
  alias Pleroma.Feed.Updates

  # By default WebSub subscriptions expire after 10 days
  @subscription_lease_seconds 864_000

  def action(conn, _params) do
    conn
    |> handle_request(conn.params)
  end

  defp handle_request(
         conn,
         %{"hub.mode" => "subscribe", "hub.topic" => topic, "hub.callback" => callback} = params
       ) do
    lease_seconds = Map.get(params, "hub.lease_seconds", @subscription_lease_seconds)
    secret = Map.get(params, "hub.secret")

    Subscriptions.subscribe(:websub, topic, callback, lease_seconds, secret: secret)
    |> handle_response(conn)
  end

  defp handle_request(conn, %{
         "hub.mode" => "unsubscribe",
         "hub.topic" => topic,
         "hub.callback" => callback
       }) do
    Subscriptions.unsubscribe(topic, callback)
    |> handle_response(conn)
  end

  defp handle_request(conn, %{"hub.mode" => "publish", "hub.topic" => topic}) do
    Updates.publish(topic)
    |> handle_response(conn)
  end

  defp handle_request(conn, %{"hub.mode" => "publish", "hub.url" => topic}) do
    # Compatability with https://pubsubhubbub.appspot.com/
    Updates.publish(topic)
    |> handle_response(conn)
  end

  defp handle_response({:ok, _message}, conn) do
    conn
    |> Plug.Conn.send_resp(202, "")
    |> Plug.Conn.halt()
  end

  defp handle_response({:error, message}, conn) when is_binary(message) do
    conn
    |> Plug.Conn.send_resp(500, message)
    |> Plug.Conn.halt()
  end

  defp handle_response({:error, reason}, conn) when is_atom(reason) do
    {status_code, message} =
      case reason do
        :failed_challenge_body -> {403, "failed_challenge_body"}
        :failed_404_response -> {403, "failed_404_response"}
        :failed_unknown_response -> {403, "failed_unknown_response"}
        :failed_unknown_error -> {500, "failed_unknown_error"}
        _ -> {500, "failed_unknown_reason"}
      end

    conn
    |> Plug.Conn.send_resp(status_code, message)
    |> Plug.Conn.halt()
  end

  defp handle_response({:error, _}, conn) do
    conn
    |> Plug.Conn.send_resp(500, "unknown error")
    |> Plug.Conn.halt()
  end
end
