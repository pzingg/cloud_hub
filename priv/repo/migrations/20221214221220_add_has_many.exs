defmodule CloudHub.Repo.Migrations.AddHasMany do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE feed_subscriptions DROP CONSTRAINT IF EXISTS feed_subscriptions_topic_id_fkey")
    alter table(:feed_subscriptions) do
      modify :topic_id, references(:feed_topics, on_delete: :delete_all)
    end

    execute("ALTER TABLE feed_updates DROP CONSTRAINT IF EXISTS feed_updates_topic_id_fkey")
    alter table(:feed_updates) do
      modify :topic_id, references(:feed_topics, on_delete: :delete_all)
    end

    execute("ALTER TABLE feed_subscription_updates DROP CONSTRAINT IF EXISTS feed_subscription_updates_update_id_fkey")
    execute("ALTER TABLE feed_subscription_updates DROP CONSTRAINT IF EXISTS feed_subscription_updates_subscription_id_fkey")
    alter table(:feed_subscription_updates) do
      modify :update_id, references(:feed_updates, on_delete: :delete_all)
      modify :subscription_id, references(:feed_subscriptions, on_delete: :delete_all)
    end
  end

  def down do
    execute("ALTER TABLE feed_subscriptions DROP CONSTRAINT IF EXISTS feed_subscriptions_topic_id_fkey")
    alter table(:feed_subscriptions) do
      modify :topic_id, references(:feed_topics)
    end

    execute("ALTER TABLE feed_updates DROP CONSTRAINT IF EXISTS feed_updates_topic_id_fkey")
    alter table(:feed_updates) do
      modify :topic_id, references(:feed_topics)
    end

    execute("ALTER TABLE feed_subscription_updates DROP CONSTRAINT IF EXISTS feed_subscription_updates_update_id_fkey")
    execute("ALTER TABLE feed_subscription_updates DROP CONSTRAINT IF EXISTS feed_subscription_updates_subscription_id_fkey")
    alter table(:feed_subscription_updates) do
      modify :update_id, references(:feed_updates)
      modify :subscription_id, references(:feed_subscriptions)
    end
  end
end
