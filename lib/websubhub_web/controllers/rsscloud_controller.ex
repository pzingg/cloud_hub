defmodule WebSubHubWeb.RSSCloudController do
  use WebSubHubWeb, :controller

  require Logger

  alias WebSubHub.Subscriptions

  def ping(conn, params) do
    Logger.error("ping not implemented")

    handle_response({:error, :unimplemented}, conn)
  end

  def please_notify(conn, _params) do
    remote_ip =
      case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
        [ip] ->
          ip

        _ ->
          with {a, b, c, d} <- conn.remote_ip do
            "#{a}.#{b}.#{c}.#{d}"
          else
            _ -> "127.0.0.1"
          end
      end
      |> case do
        "127.0.0.1" -> "localhost"
        ip_or_address -> ip_or_address
      end

    result =
      with {:ok, {callback, topics, diff_domain}} <-
             parse_body_params(conn.body_params, remote_ip) do
        {good, bad} =
          topics
          |> Enum.map(fn topic ->
            Subscriptions.subscribe(:rsscloud, topic, callback, 90_000, diff_domain: diff_domain)
          end)
          |> Enum.split_with(fn res -> elem(res, 0) == :ok end)

        case bad do
          [] -> hd(good)
          _ -> hd(bad)
        end
      else
        error -> error
      end

    handle_response(result, conn)
  end

  defp parse_body_params(
         %{"protocol" => protocol, "port" => port, "path" => path} = params,
         remote_ip
       ) do
    scheme =
      case protocol do
        "http-rest" -> "http"
        "https-rest" -> "https"
        _ -> nil
      end

    port =
      case Integer.parse(port) do
        {p, ""} -> p
        _ -> nil
      end

    cond do
      is_nil(scheme) ->
        Logger.error("protocol '#{protocol}' invalid")
        {:error, :invalid_request}

      is_nil(port) ->
        Logger.error("port '#{port}' invalid")
        {:error, :invalid_request}

      String.first(path) != "/" ->
        Logger.error("path '#{path}' invalid")
        {:error, :invalid_request}

      true ->
        Enum.reduce(params, [], fn {k, v}, acc ->
          if Regex.match?(~r/^url\d+$/, k) do
            [v | acc]
          else
            acc
          end
        end)
        |> case do
          [] ->
            Logger.error("no urls parsed")
            {:error, :invalid_request}

          topics ->
            domain =
              case Map.get(params, "domain", remote_ip) do
                "127.0.0.1" -> "localhost"
                ip_or_address -> ip_or_address
              end

            callback = "#{scheme}://#{domain}:#{port}#{path}"

            # diff_domain = domain != remote_ip
            diff_domain = Map.has_key?(params, "domain")
            {:ok, {callback, topics, diff_domain}}
        end
    end
  end

  defp parse_body_params(_invalid_params, _remote_ip), do: {:error, :invalid_request}

  defp handle_response({:ok, _subscription}, conn) do
    conn
    |> Phoenix.Controller.json(%{success: true, msg: "subscribed"})
    |> Plug.Conn.halt()
  end

  defp handle_response({:error, message}, conn) when is_binary(message) do
    conn
    |> Plug.Conn.put_status(500)
    |> Phoenix.Controller.json(%{success: false, msg: message})
    |> Plug.Conn.halt()
  end

  defp handle_response({:error, reason}, conn) when is_atom(reason) do
    {status_code, message} =
      case reason do
        :invalid_request -> {400, "invalid_request"}
        :failed_challenge_body -> {403, "failed_challenge_body"}
        :failed_404_response -> {403, "failed_404_response"}
        :failed_unknown_response -> {403, "failed_unknown_response"}
        :failed_unknown_error -> {500, "failed_unknown_error"}
        :unimplemented -> {500, "unimplemented"}
        _ -> {500, "failed_unknown_reason"}
      end

    conn
    |> Plug.Conn.put_status(status_code)
    |> Phoenix.Controller.json(%{success: false, msg: message})
    |> Plug.Conn.halt()
  end

  defp handle_response({:error, error}, conn) do
    Logger.error("RSSCloudController unknown error: #{inspect(error)}")

    conn
    |> Plug.Conn.put_status(500)
    |> Phoenix.Controller.json(%{success: false, msg: "unknown error"})
    |> Plug.Conn.halt()
  end
end
