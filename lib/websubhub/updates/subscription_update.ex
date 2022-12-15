defmodule WebSubHub.Updates.SubscriptionUpdate do
  use Ecto.Schema
  import Ecto.Changeset

  schema "subscription_updates" do
    belongs_to :update, WebSubHub.Updates.Update
    belongs_to :subscription, WebSubHub.Subscriptions.Subscription

    field :pushed_at, :naive_datetime
    field :status_code, :integer

    timestamps()
  end

  @doc false
  def changeset(topic, attrs) do
    topic
    |> cast(attrs, [:update_id, :subscription_id, :pushed_at, :status_code])
    |> validate_required([:pushed_at, :status_code])
    |> foreign_key_constraint(:update_id)
    |> foreign_key_constraint(:subscription_id)
  end
end
