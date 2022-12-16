defmodule CloudHubWeb.WebSubControllerTest do
  use CloudHubWeb.ConnCase

  setup do
    [subscriber_url: "http://localhost/subscriber/callback"]
  end

  test "subscribing to a specific topic", %{
    conn: conn,
    subscriber_url: callback_url
  } do
    Tesla.Mock.mock(fn
      %{method: :get, url: ^callback_url, query: query} ->
        query = Map.new(query)

        if Map.has_key?(query, "hub.challenge") do
          %Tesla.Env{
            status: 200,
            body: Map.get(query, "hub.challenge"),
            headers: [{"content-type", "text/plain"}]
          }
        else
          %Tesla.Env{status: 400, body: "no challenge", headers: [{"content-type", "text/plain"}]}
        end

      _not_matched ->
        %Tesla.Env{
          status: 404,
          body: "not found",
          headers: [{"content-type", "text/plain"}]
        }
    end)

    params = %{
      "hub.mode" => "subscribe",
      "hub.topic" => "http://localhost:1234/topic",
      "hub.callback" => callback_url
    }

    conn = form_post(conn, "/hub", params)

    assert response(conn, 202) =~ ""
  end

  test "subscribing with an invalid response", %{
    conn: conn,
    subscriber_url: callback_url
  } do
    Tesla.Mock.mock(fn
      %{method: :get, url: ^callback_url} ->
        %Tesla.Env{
          status: 200,
          body: "whut?",
          headers: [{"content-type", "text/plain"}]
        }

      _not_matched ->
        %Tesla.Env{
          status: 404,
          body: "not found",
          headers: [{"content-type", "text/plain"}]
        }
    end)

    params = %{
      "hub.mode" => "subscribe",
      "hub.topic" => "http://localhost:1234/topic",
      "hub.callback" => callback_url
    }

    conn = form_post(conn, "/hub", params)

    assert response(conn, 403) =~ "failed_challenge_body"
  end

  defp form_post(conn, path, params) do
    conn
    |> Plug.Conn.put_req_header("content-type", "application/x-www-form-urlencoded")
    |> post(path, params)
  end
end
