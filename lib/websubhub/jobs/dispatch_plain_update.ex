defmodule WebSubHub.Jobs.DispatchPlainUpdate do
  use Oban.Worker, queue: :updates, max_attempts: 3
  require Logger

  alias WebSubHub.HTTPClient

  alias WebSubHub.Updates

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "update_id" => update_id,
          "subscription_id" => subscription_id,
          "subscription_api" => api,
          "callback_url" => callback_url,
          "secret" => secret
        }
      }) do
    update = WebSubHub.Updates.get_update_and_topic(update_id)
    topic_url = update.topic.url
    api = String.to_existing_atom(api)

    perform_request(api, callback_url, topic_url, update, secret)
    |> log_request(update.id, subscription_id)
  end

  defp perform_request(:websub, callback_url, topic_url, update, secret) do
    links = [
      "<#{topic_url}>; rel=self",
      "<https://websubhub.com/hub>; rel=hub"
    ]

    headers = [
      {"content-type", update.content_type},
      {"link", Enum.join(links, ", ")}
    ]

    headers =
      if secret do
        hmac = :crypto.mac(:hmac, :sha256, secret, update.body) |> Base.encode16(case: :lower)
        [{"x-hub-signature", "sha256=" <> hmac} | headers]
      else
        headers
      end

    case HTTPClient.post(callback_url, update.body, headers) do
      {:ok, %Tesla.Env{status: code}} when code >= 200 and code < 300 ->
        Logger.debug("WebSub got OK response from #{callback_url}")
        {:ok, code}

      {:ok, %Tesla.Env{status: 410}} ->
        # Invalidate this subscription
        {:ok, 410}

      {:ok, %Tesla.Env{status: code}} ->
        {:failed, code}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp perform_request(:rsscloud, callback_url, topic_url, _update, _secret) do
    params = %{url: topic_url}

    case HTTPClient.post_form(callback_url, params) do
      {:ok, %Tesla.Env{status: code}} when code >= 200 and code < 300 ->
        Logger.debug("RSSCloud got OK response from #{callback_url}")
        {:ok, code}

      {:ok, %Tesla.Env{status: 410}} ->
        # Invalidate this subscription
        {:ok, 410}

      {:ok, %Tesla.Env{status: code}} ->
        {:failed, code}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp perform_request(api, _callback_url, _topic_url, _update, _secret) do
    Logger.error("No such api #{api}")
    {:error, "invalid api"}
  end

  defp log_request(res, update_id, subscription_id) do
    status_code =
      case res do
        {_, code} when is_integer(code) ->
          code

        _ ->
          nil
      end

    Updates.create_subscription_update(update_id, subscription_id, status_code)

    res
  end
end
