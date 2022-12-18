defmodule Pleroma.Workers.DispatchFeedUpdateWorker do
  use Oban.Worker, queue: :feed_updates, max_attempts: 3
  require Logger

  alias Pleroma.HTTP

  alias Pleroma.Feed.Update
  alias Pleroma.Feed.Updates

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
    with %Update{} = update <- Pleroma.Feed.Updates.get_update_and_topic(update_id) do
      topic_url = update.topic.url
      api = String.to_existing_atom(api)

      perform_request(api, callback_url, topic_url, update, secret)
      |> log_request(update.id, subscription_id)
    else
      # In case update has already been removed.
      _ ->
        Logger.error("Could not find update #{update_id}")
        {:error, "Update not found"}
    end
  end

  defp perform_request(:websub, callback_url, topic_url, update, secret) do
    links = [
      "<#{topic_url}>; rel=self",
      "<https://cloud_hub.com/hub>; rel=hub"
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

    case HTTP.post(callback_url, update.body, headers) do
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
    body = %{url: topic_url} |> URI.encode_query()
    headers = [{"content-type", "application/x-www-form-urlencoded"}]

    case HTTP.post(callback_url, body, headers) do
      {:ok, %Tesla.Env{status: code}} when code >= 200 and code < 300 ->
        Logger.debug("RSSCloud got OK response from #{callback_url}")
        {:ok, code}

      {:ok, %Tesla.Env{status: 410}} ->
        # Invalidate this subscription
        {:ok, 410}

      {:ok, %Tesla.Env{status: code}} ->
        {:failed, code}

      {:error, reason} ->
        Logger.error("RSSCloud got ERROR at #{callback_url}: #{inspect(reason)}")
        {:error, 500}
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
          599
      end

    # Will fail if either update at update_id or subscription at subscription_id is gone
    _ =
      case Updates.create_subscription_update(update_id, subscription_id, status_code) do
        {:ok, %{id: id}} ->
          Logger.debug("New update #{id} for subscription #{subscription_id}")

        {:error, changeset} ->
          Logger.error("Failed to create update for subscription #{subscription_id}")
          Logger.error("  -> #{inspect(changeset.errors)}")
      end

    res
  end
end
