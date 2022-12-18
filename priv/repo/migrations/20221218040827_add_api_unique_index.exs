defmodule CloudHub.Repo.Migrations.AddApiUniqueIndex do
  use Ecto.Migration

  def change do
    drop unique_index(:subscriptions, [:topic_id, :callback_url])
    create unique_index(:subscriptions, [:api, :topic_id, :callback_url])
  end
end
