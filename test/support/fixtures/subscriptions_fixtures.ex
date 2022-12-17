defmodule WebSubHub.SubscriptionsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `WebSubHub.Subscriptions` context.
  """

  alias WebSubHub.Repo
  alias WebSubHub.Subscriptions.Subscription
  alias WebSubHub.Subscriptions.Topic

  @doc """
  Generate a topic.
  """
  def topic_fixture(attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        url: "some url"
      })

    {:ok, topic} =
      %Topic{}
      |> Topic.changeset(attrs)
      |> Repo.insert()

    topic
  end

  @doc """
  Generate a subscription.
  """
  def subscription_fixture(attrs \\ %{}) do
    topic = topic_fixture(attrs)

    attrs =
      attrs
      |> Enum.into(%{
        api: :websub,
        callback_url: "some callback_url",
        lease_seconds: 42,
        secret: "some secret",
        topic_id: topic.id
      })

    {:ok, subscription} =
      %Subscription{}
      |> Subscription.changeset(attrs)
      |> Repo.insert()

    subscription
  end
end
