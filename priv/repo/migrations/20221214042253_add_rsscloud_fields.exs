defmodule CloudHub.Repo.Migrations.AddRSSCloudFields do
  use Ecto.Migration

  def change do
    alter table(:feed_subscriptions) do
      add :api, :string
      add :diff_domain, :boolean, null: false, default: false
    end
  end
end
