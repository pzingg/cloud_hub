defmodule CloudHub.Repo.Migrations.LongerEverything do
  use Ecto.Migration

  def change do
    alter table(:feed_topics) do
      modify :url, :text
    end

    alter table(:feed_subscriptions) do
      modify :callback_url, :text
    end
  end
end
