defmodule WebSubHub.Subscriptions.Topic do
  use Ecto.Schema
  import Ecto.Changeset

  schema "topics" do
    # TODO field :expires_at, :naive_datetime
    has_many :subscriptions, WebSubHub.Subscriptions.Subscription
    has_many :updates, WebSubHub.Updates.Update

    field :url, :string

    timestamps()
  end

  @doc false
  def changeset(topic, attrs) do
    # TODO expires_at: :required
    topic
    |> cast(attrs, [:url])
    |> validate_required([:url])
    |> unique_constraint([:url])
  end
end
