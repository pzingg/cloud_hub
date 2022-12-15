defmodule Pleroma.Feed.WebSubControllerTest do
  use CloudHubWeb.ConnCase

  require Logger

  setup do
    {:ok, pid} = FakeServer.start(:my_server)
    subscriber_port = FakeServer.port!(pid)

    on_exit(fn ->
      FakeServer.stop(pid)
    end)

    [subscriber_pid: pid, subscriber_port: subscriber_port]
  end

  test "subscribing to a specific topic with diff_domain = true", %{
    conn: conn,
    subscriber_pid: subscriber_pid,
    subscriber_port: subscriber_port
  } do
    :ok =
      FakeServer.put_route(
        subscriber_pid,
        "/callback",
        fn %{
             query: %{
               "url" => _url,
               "challenge" => challenge
             }
           } ->
          FakeServer.Response.ok(challenge)
        end
      )

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
    subscriber_pid: subscriber_pid,
    subscriber_port: subscriber_port
  } do
    :ok =
      FakeServer.put_route(subscriber_pid, "/callback", fn
        %FakeServer.Request{method: "POST", body: _body} ->
          FakeServer.Response.ok("ok")
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
    subscriber_pid: subscriber_pid,
    subscriber_port: subscriber_port
  } do
    :ok = FakeServer.put_route(subscriber_pid, "/callback", FakeServer.Response.ok("whut?"))

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
