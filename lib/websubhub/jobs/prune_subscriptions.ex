defmodule WebSubHub.Jobs.PruneSubscriptions do
  use Oban.Worker, queue: :prune_subscriptions, max_attempts: 1
  require Logger

  alias WebSubHub.Subscriptions
  alias WebSubHub.Subscriptions.Subscription

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

    case Subscriptions.delete_all_inactive_subscriptions(expiring) do
      {:error, reason} ->
        Logger.error("Transaction error deleting subscriptions: #{reason}")

      {count, _} ->
        Logger.error("Deleted #{count} subscriptions")
    end

    :ok
  end
end
