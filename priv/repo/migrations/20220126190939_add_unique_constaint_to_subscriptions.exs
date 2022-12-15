defmodule CloudHub.Repo.Migrations.AddUniqueConstaintToSubscriptions do
  use Ecto.Migration

  def change do
    create unique_index(:feed_subscriptions, [:topic_id, :callback_url])
  end
end
