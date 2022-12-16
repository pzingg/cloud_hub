defmodule Pleroma.Feed.RSSCloudTest do
  use CloudHub.DataCase

  require Logger

  alias Pleroma.Feed.Subscription
  alias Pleroma.Feed.Subscriptions
  alias Pleroma.Feed.Updates
  alias Pleroma.Feed.Subscription
  alias Pleroma.Feed.SubscriptionUpdate
  alias Pleroma.Feed.Topic

  @lease_seconds 1

  test "delete_all subscriptions cascades" do
    %{topics: _, subscriptions: subscriptions} = build_data()

    subscription_updates =
      subscriptions
      |> Enum.map(fn subscription ->
        subscription = Repo.preload(subscription, :topic)
        topic = subscription.topic
        env = %Tesla.Env{status: 200, body: topic.url}

        Enum.map(1..5, fn _i ->
          {:ok, update} = Updates.create_update(topic, env)

          Enum.map(1..5, fn _j ->
            {:ok, subscription_update} =
              Updates.create_subscription_update(update.id, subscription.id, 200)

            subscription_update
          end)
        end)
      end)
      |> List.flatten()

    assert 100 == Enum.count(subscription_updates)

    expiring =
      DateTime.utc_now()
      |> DateTime.add(60, :second)

    assert {4, 2, _} = Subscriptions.delete_all_inactive_subscriptions(expiring)
    assert 0 == SubscriptionUpdate |> Repo.aggregate(:count, :id)
  end

  test "removing all subscriptions for a topic sets an expiration" do
    %{topics: topics, subscriptions: _} = build_data()

    [topic1_exp, topic2_exp] =
      topics
      |> Enum.with_index(fn topic, i ->
        topic_url = topic.url
        %Topic{subscriptions: subscriptions} = Repo.preload(topic, :subscriptions)

        now = NaiveDateTime.utc_now()

        # Remove one sub in topic1
        # Remove two subs (all of them) in topic2
        0..i
        |> Enum.map(fn j ->
          Enum.at(subscriptions, j)
          |> Subscriptions.delete_subscription(now)
        end)

        %Topic{url: url, expires_at: expires_at} = Subscriptions.get_topic_by_url(topic_url)
        expires_at
      end)

    assert NaiveDateTime.compare(topic1_exp, ~N[2040-01-01 00:00:00]) == :gt
    # After removing all subs in topic2, topic2 will expire soon!
    assert NaiveDateTime.compare(topic2_exp, ~N[2040-01-01 00:00:00]) == :lt
  end

  def build_data() do
    {:ok, topic1} = Subscriptions.find_or_create_topic("http://publisher/topic1")
    {:ok, topic2} = Subscriptions.find_or_create_topic("http://publisher/topic2")
    assert topic1.id != topic2.id

    {:ok, sub1_topic1} =
      Subscriptions.find_or_create_subscription(
        :websub,
        topic1,
        "http://subscriber/sub1",
        @lease_seconds,
        []
      )

    {:ok, sub1_topic2} =
      Subscriptions.find_or_create_subscription(
        :websub,
        topic2,
        "http://subscriber/sub1",
        @lease_seconds,
        []
      )

    {:ok, sub2_topic1} =
      Subscriptions.find_or_create_subscription(
        :websub,
        topic1,
        "http://subscriber/sub2",
        @lease_seconds,
        []
      )

    {:ok, sub2_topic2} =
      Subscriptions.find_or_create_subscription(
        :websub,
        topic2,
        "http://subscriber/sub2",
        @lease_seconds,
        []
      )

    topic1 = Repo.preload(topic1, :subscriptions)
    assert 2 == Enum.count(topic1.subscriptions)

    topic2 = Repo.preload(topic2, :subscriptions)
    assert 2 == Enum.count(topic2.subscriptions)

    %{
      topics: [topic1, topic2],
      subscriptions: [sub1_topic1, sub1_topic2, sub2_topic1, sub2_topic2]
    }
  end
end
