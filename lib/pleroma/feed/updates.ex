defmodule Pleroma.Feed.Updates do
  @moduledoc """
  The Updates context.
  """
  require Logger

  import Ecto.Query, warn: false
  alias CloudHub.Repo
  alias Pleroma.HTTP

  alias Pleroma.Feed.Subscriptions
  alias Pleroma.Feed.SubscriptionUpdate
  alias Pleroma.Feed.Topic
  alias Pleroma.Feed.Update

  def publish(topic_url) do
    case Subscriptions.get_topic_by_url(topic_url) do
      # Get all active subscriptions and publish the update to them
      %Topic{} = topic ->
        case HTTP.get(topic.url) do
          {:ok, %Tesla.Env{status: code} = env}
          when code >= 200 and code < 300 ->
            with {:ok, update} <- create_update(topic, env) do
              # Realistically we should do all of this async, for now we'll do querying line and dispatch async
              subscribers = Subscriptions.list_active_topic_subscriptions(topic)

              Enum.each(subscribers, fn subscription ->
                Logger.debug("Queueing dispatch to #{subscription.callback_url}")

                Pleroma.Workers.DispatchFeedUpdateWorker.new(%{
                  callback_url: subscription.callback_url,
                  update_id: update.id,
                  subscription_id: subscription.id,
                  subscription_api: subscription.api,
                  secret: subscription.secret
                })
                |> Oban.insert()
              end)

              Logger.info("Updates.publish: Sending updates for #{topic_url}")
              {:ok, update}
            else
              {:error, _changeset} ->
                Logger.error("Updates.publish: Could not create new record for #{topic.url}")
                {:error, "Error creating update record."}
            end

          _ ->
            Logger.error("Updates.publish: Unsuccessful response code for #{topic.url}")
            {:error, "Publish URL did not return a successful status code."}
        end

      nil ->
        # Nothing found
        Logger.error("Updates.publish: Did not find topic for #{topic_url}")
        {:error, "Topic not found for topic URL."}

      err ->
        Logger.error("Updates.publish: Unknown error #{inspect(err)}")
        {:error, "Unknown error."}
    end
  end

  def create_update(%Topic{} = topic, %Tesla.Env{body: body, headers: headers} = env) when is_binary(body) do
    content_type = Tesla.get_header(env, "content-type") || "application/octet-stream"

    # BACKPORT
    %Update{
      topic_id: topic.id
    }
    |> Update.changeset(%{
      body: body,
      headers: headers,
      content_type: content_type,
      links: Tesla.get_headers(env, "link"),
      hash: :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)
    })
    |> Repo.insert()
  end

  @doc """
  Create a subscription update, uses ID's for quick insertion
  """
  def create_subscription_update(update_id, subscription_id, status_code)
      when is_integer(update_id) and is_integer(subscription_id) do
    %SubscriptionUpdate{
      update_id: update_id,
      subscription_id: subscription_id
    }
    |> SubscriptionUpdate.changeset(%{
      pushed_at: NaiveDateTime.utc_now(),
      status_code: status_code
    })
    |> Repo.insert()
  end

  def get_update(id) do
    Repo.get(Update, id)
  end

  def get_update_and_topic(id) do
    Repo.get(Update, id) |> Repo.preload(:topic)
  end

  def get_subscription_update(id) do
    Repo.get(SubscriptionUpdate, id)
  end

  def count_30min_updates do
    now = NaiveDateTime.utc_now()
    time_ago = NaiveDateTime.add(now, -1800)

    Repo.one(
      from u in Update,
        where: u.inserted_at > ^time_ago and u.inserted_at < ^now,
        select: count(u.id)
    )
  end

  def count_30min_subscription_updates do
    now = NaiveDateTime.utc_now()
    time_ago = NaiveDateTime.add(now, -1800)

    Repo.one(
      from u in SubscriptionUpdate,
        where: u.inserted_at > ^time_ago and u.inserted_at < ^now,
        select: count(u.id)
    )
  end
end
