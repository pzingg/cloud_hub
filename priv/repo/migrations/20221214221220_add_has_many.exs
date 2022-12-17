defmodule WebSubHub.Repo.Migrations.AddHasMany do
  use Ecto.Migration

  def up do
    "ALTER TABLE subscriptions DROP CONSTRAINT subscriptions_topic_id_fkey"
    |> execute()

    alter table(:subscriptions) do
      modify :topic_id, references(:topics, on_delete: :delete_all)
    end

    "ALTER TABLE updates DROP CONSTRAINT updates_topic_id_fkey"
    |> execute()

    alter table(:updates) do
      modify :topic_id, references(:topics, on_delete: :delete_all)
    end

    "ALTER TABLE subscription_updates DROP CONSTRAINT subscription_updates_update_id_fkey"
    |> execute()

    "ALTER TABLE subscription_updates DROP CONSTRAINT subscription_updates_subscription_id_fkey"
    |> execute()

    alter table(:subscription_updates) do
      modify :update_id, references(:updates, on_delete: :delete_all)
      modify :subscription_id, references(:subscriptions, on_delete: :delete_all)
    end
  end

  def down do
    "ALTER TABLE subscriptions DROP CONSTRAINT subscriptions_topic_id_fkey"
    |> execute()

    alter table(:subscriptions) do
      modify :topic_id, references(:topics)
    end

    "ALTER TABLE updates DROP CONSTRAINT updates_topic_id_fkey"
    |> execute()

    alter table(:updates) do
      modify :topic_id, references(:topics)
    end

    "ALTER TABLE subscription_updates DROP CONSTRAINT subscription_updates_update_id_fkey"
    |> execute()

    "ALTER TABLE subscription_updates DROP CONSTRAINT subscription_updates_subscription_id_fkey"
    |> execute()

    alter table(:subscription_updates) do
      modify :update_id, references(:updates)
      modify :subscription_id, references(:subscriptions)
    end
  end
end
