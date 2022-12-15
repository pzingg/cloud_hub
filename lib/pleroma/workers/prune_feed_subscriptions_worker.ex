defmodule Pleroma.Workers.PruneFeedSubscriptionsWorker do
  use Oban.Worker, queue: :prune_feed_subscriptions, max_attempts: 1
  require Logger

  alias Pleroma.Feed.Subscription
  alias Pleroma.Feed.Subscriptions

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

    Logger.error("Pruning subscriptions expiring before #{expiring}")

    ids_to_delete =
      Subscriptions.list_inactive_subscriptions(expiring)
      |> Enum.map(fn %Subscription{id: id} = subscription ->
        _ = Subscriptions.final_unsubscribe(subscription)
        id
      end)

    Logger.error("Unsubscribed #{Enum.count(ids_to_delete)} subscriptions")

    {s_count, su_count} = Subscriptions.delete_all_inactive_subscriptions(expiring)
    Logger.error("Deleted #{s_count} subscriptions")
    Logger.error("Deleted #{su_count} subscription updates")

    :ok
  end
end
