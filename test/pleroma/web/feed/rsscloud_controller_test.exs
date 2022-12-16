defmodule Pleroma.Feed.RSSCloudControllerTest do
  use CloudHubWeb.ConnCase

  setup do
    [subscriber_port: Enum.random(7000..8000)]
  end

  test "subscribing to a specific topic with diff_domain = true", %{
    conn: conn,
    subscriber_port: subscriber_port
  } do
    callback_url = "http://localhost:#{subscriber_port}/callback"

    Tesla.Mock.mock(fn
      %{method: :get, url: ^callback_url, query: query} ->
        query = Map.new(query)

        if Map.has_key?(query, "challenge") && Map.has_key?(query, "url") do
          %Tesla.Env{
            status: 200,
            body: Map.get(query, "challenge"),
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
      "protocol" => "http-rest",
      "domain" => "localhost",
      "port" => "#{subscriber_port}",
      "path" => "/callback",
      "notifyProcedure" => "",
      "url1" => "http://localhost:1234/topic"
    }

    conn = form_post(conn, "/rsscloud/pleaseNotify", params)

    assert response(conn, 200) =~ ""
  end

  test "subscribing to a specific topic with diff_domain = false", %{
    conn: conn,
    subscriber_port: subscriber_port
  } do
    callback_url = "http://localhost:#{subscriber_port}/callback"

    Tesla.Mock.mock(fn
      %{method: :post, url: ^callback_url} ->
        %Tesla.Env{status: 200, body: "ok", headers: [{"content-type", "text/plain"}]}

      _not_matched ->
        %Tesla.Env{
          status: 404,
          body: "not found",
          headers: [{"content-type", "text/plain"}]
        }
    end)

    params = %{
      "protocol" => "http-rest",
      "port" => "#{subscriber_port}",
      "path" => "/callback",
      "notifyProcedure" => "",
      "url1" => "http://localhost:1234/topic"
    }

    conn = form_post(conn, "/rsscloud/pleaseNotify", params)

    assert response(conn, 200) =~ ""
  end

  test "subscribing with an invalid response", %{
    conn: conn,
    subscriber_port: subscriber_port
  } do
    callback_url = "http://localhost:#{subscriber_port}/callback"

    Tesla.Mock.mock(fn
      %{method: :get, url: ^callback_url} ->
        %Tesla.Env{status: 200, body: "wrong answer", headers: [{"content-type", "text/plain"}]}

      _not_matched ->
        %Tesla.Env{
          status: 404,
          body: "not found",
          headers: [{"content-type", "text/plain"}]
        }
    end)

    params = %{
      "protocol" => "http-rest",
      "domain" => "localhost",
      "port" => "#{subscriber_port}",
      "path" => "/callback",
      "notifyProcedure" => "",
      "url1" => "http://localhost:1234/topic"
    }

    conn = form_post(conn, "/rsscloud/pleaseNotify", params)

    assert response(conn, 403) =~ "failed_challenge_body"
  end

  defp form_post(conn, path, params) do
    conn
    |> Plug.Conn.put_req_header("content-type", "application/x-www-form-urlencoded")
    |> post(path, params)
  end
end
