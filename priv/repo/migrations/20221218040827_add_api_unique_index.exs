defmodule CloudHub.Repo.Migrations.AddApiUniqueIndex do
  use Ecto.Migration

  def change do
    drop unique_index(:feed_subscriptions, [:topic_id, :callback_url])
    create unique_index(:feed_subscriptions, [:api, :topic_id, :callback_url])
  end
end
