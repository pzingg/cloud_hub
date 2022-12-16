defmodule Pleroma.Feed.Subscription do
  use Ecto.Schema
  import Ecto.Changeset

  schema "feed_subscriptions" do
    belongs_to :topic, Pleroma.Feed.Topic
    has_many :subscription_updates, Pleroma.Feed.SubscriptionUpdate

    field :callback_url, :string
    field :lease_seconds, :float
    field :expires_at, :naive_datetime
    field :secret, :string
    field :diff_domain, :boolean
    field :api, Ecto.Enum, values: [:websub, :rsscloud]

    timestamps()
  end

  @doc false
  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [
      :topic_id,
      :api,
      :callback_url,
      :lease_seconds,
      :expires_at,
      :secret,
      :diff_domain
    ])
    |> validate_required([:api, :callback_url, :lease_seconds, :expires_at])
    |> validate_method()
    |> foreign_key_constraint(:topic_id)
    |> unique_constraint([:api, :topic_id, :callback_url])
  end

  defp validate_method(changeset) do
    api = get_field(changeset, :api)

    case api do
      :websub -> changeset
      :rsscloud -> validate_required(changeset, :diff_domain)
      nil -> add_error(changeset, :api, "is required")
      other -> add_error(changeset, :api, "is invalid: #{other}")
    end
  end
end
