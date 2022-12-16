defmodule Pleroma.Feed.Topic do
  use Ecto.Schema
  import Ecto.Changeset

  schema "feed_topics" do
    # BACKPORT
    has_many :subscriptions, Pleroma.Feed.Subscription
    has_many :updates, Pleroma.Feed.Update

    field :url, :string
    field :expires_at, :naive_datetime

    timestamps()
  end

  @doc false
  def changeset(topic, attrs) do
    topic
    |> cast(attrs, [:url, :expires_at])
    |> validate_required([:url])
    |> unique_constraint([:url])
  end
end
