defmodule CloudHub.Repo.Migrations.CreateTopics do
  use Ecto.Migration

  def change do
    create table(:feed_topics) do
      add :url, :string

      timestamps()
    end

    create unique_index(:feed_topics, [:url])

    create table(:feed_subscriptions) do
      add :topic_id, references(:feed_topics)
      add :callback_url, :string
      add :lease_seconds, :float
      add :expires_at, :naive_datetime
      add :secret, :string, nullable: true

      timestamps()
    end

    create table(:feed_updates) do
      add :topic_id, references(:feed_topics)

      add :body, :binary
      add :headers, :binary
      add :content_type, :text
      add :links, {:array, :text}
      add :hash, :string

      timestamps()
    end

    create table(:feed_subscription_updates) do
      add :update_id, references(:feed_updates)
      add :subscription_id, references(:feed_subscriptions)
      add :pushed_at, :naive_datetime
      add :status_code, :integer, nullable: true

      timestamps()
    end
  end
end
