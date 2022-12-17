defmodule Pleroma.Workers.PruneFeedSubscriptionsWorker do
  use Oban.Worker, queue: :prune_feed_subscriptions, max_attempts: 1
  require Logger

  alias Pleroma.Feed.Subscription
  alias Pleroma.Feed.Subscriptions

  # Orphaned topics live for another 3 hours
  @topic_lease_seconds 10_800

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    expiring =
      case Map.get(args, "expiring") do
        expiring when is_binary(expiring) ->
          {:ok, expiring, _} = DateTime.from_iso8601(expiring)
          DateTime.to_naive(expiring)

        _ ->
          NaiveDateTime.utc_now()
      end

    Logger.error("Pruning subscriptions and topics expiring before #{expiring}")

    _ =
      Subscriptions.list_inactive_subscriptions(expiring)
      |> Enum.map(fn %Subscription{id: id} = subscription ->
        _ = Subscriptions.final_unsubscribe(subscription)
        id
      end)

    _ =
      case Subscriptions.delete_all_inactive_subscriptions(@topic_lease_seconds, expiring) do
        {:error, reason} ->
          Logger.error("Transaction error deleting inactive subscriptions: #{reason}")

        {count, _, _} ->
          Logger.error("Deleted #{count} inactive subscriptions")
      end

    {count, _} = Subscriptions.delete_all_inactive_topics(expiring)
    Logger.error("Deleted #{count} inactive topics")

    :ok
  end
end
