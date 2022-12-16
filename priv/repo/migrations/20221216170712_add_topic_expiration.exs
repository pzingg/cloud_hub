defmodule CloudHub.Repo.Migrations.AddTopicExpiration do
  use Ecto.Migration

  def change do
    alter table(:feed_topics) do
      add :expires_at, :naive_datetime
    end

    create index(:feed_subscriptions, :expires_at)
    create index(:feed_topics, :expires_at)
  end
end
