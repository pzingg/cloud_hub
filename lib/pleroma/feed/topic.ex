defmodule Pleroma.Feed.Topic do
  use Ecto.Schema
  import Ecto.Changeset

  schema "feed_topics" do
    has_many :feed_subscriptions, Pleroma.Feed.Subscription
    has_many :updates, Pleroma.Feed.Update

    field :url, :string

    timestamps()
  end

  @doc false
  def changeset(topic, attrs) do
    topic
    |> cast(attrs, [:url])
    |> validate_required([:url])
    |> unique_constraint([:url])
  end
end
