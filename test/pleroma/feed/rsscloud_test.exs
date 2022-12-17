defmodule Pleroma.Feed.RSSCloudTest do
  use CloudHub.DataCase
  use Oban.Testing, repo: CloudHub.Repo

  require Logger

  @subscription_lease_seconds 90_000
  @content_type_text_plain [{"content-type", "text/plain"}]
  @html_body """
  <!doctype html>
  <html lang=en>
    <head>
      <meta charset=utf-8>
      <title>blah</title>
    </head>
    <body>
      <p>I'm the content</p>
    </body>
  </html>
  """
  @text_body "Hello world"
  @json_body %{"hello" => "world"}
  @xml_body """
  <?xml version="1.0" encoding="UTF-8"?>
  <rss version="2.0">
    <channel>
      <title>Scripting News</title>
      <link>http://scripting.com/</link>
      <description>It's even worse than it appears..</description>
      <pubDate>Wed, 14 Dec 2022 16:36:13 GMT</pubDate>
      <lastBuildDate>Wed, 14 Dec 2022 17:54:45 GMT</lastBuildDate>
      <item>
        <description>The idea of <a href="http://textcasting.org/">textcasting</a> is like podcasting.</description>    <pubDate>Wed, 14 Dec 2022 13:44:21 GMT</pubDate>
        <link>http://scripting.com/2022/12/14.html#a134421</link>
        <guid>http://scripting.com/2022/12/14.html#a134421</guid>
      </item>
    </channel>
  </rss>
  """

  @moduledoc """
  Implements the tests described by https://websub.rocks/hub
  """

  alias Pleroma.Feed.Updates
  alias Pleroma.Feed.Subscriptions

  describe "100 - Typical subscriber request" do
    @doc """
    This subscriber will include only the parameters hub.mode, hub.topic and hub.callback. The hub should deliver notifications with no signature.
    """

    setup :setup_html_publisher

    test "100 - Typical subscriber request", %{
      subscriber_url: callback_url,
      publisher_url: topic_url
    } do
      assert {:ok, subscription} =
               Subscriptions.subscribe(
                 :rsscloud,
                 topic_url,
                 callback_url,
                 @subscription_lease_seconds
               )

      assert {:ok, update} = Updates.publish(topic_url)
      assert update.content_type == "text/html; charset=UTF-8"

      assert_enqueued(
        worker: Pleroma.Workers.DispatchFeedUpdateWorker,
        args: %{
          update_id: update.id,
          subscription_id: subscription.id,
          subscription_api: "rsscloud",
          callback_url: callback_url,
          secret: nil
        }
      )

      assert %{success: 1, failure: 0} = Oban.drain_queue(queue: :feed_updates)

      assert TeslaMockAgent.hits(:publisher) == 1
      assert TeslaMockAgent.hits(:subscriber) == 2

      [_challenge, publish] = TeslaMockAgent.access_list(:subscriber)
      assert publish.body == "url=" <> URI.encode_www_form(topic_url)

      assert Tesla.get_header(publish, "content-type") ==
               "application/x-www-form-urlencoded"
    end

    test "does not get publish if already unsubscribed", %{
      subscriber_url: callback_url,
      publisher_url: topic_url
    } do
      assert {:ok, subscription} =
               Subscriptions.subscribe(
                 :rsscloud,
                 topic_url,
                 callback_url,
                 @subscription_lease_seconds
               )

      {:ok, _} = Subscriptions.unsubscribe(topic_url, callback_url)

      # Quick sleep
      :timer.sleep(1000)

      assert {:ok, update} = Updates.publish(topic_url)

      refute_enqueued(
        worker: Pleroma.Workers.DispatchFeedUpdateWorker,
        args: %{
          update_id: update.id,
          subscription_id: subscription.id,
          callback_url: callback_url,
          secret: nil
        }
      )

      assert TeslaMockAgent.hits(:publisher) == 1

      # Note that :rsscloud does not notify on unsubscription
      assert TeslaMockAgent.hits(:subscriber) == 1
    end
  end

  describe "102 - Subscriber sends additional parameters" do
    @doc """
    This subscriber will include some additional parameters in the request, which must be ignored by the hub if the hub doesn't recognize them.
    """
    test "102 - Subscriber sends additional parameters", %{} do
    end
  end

  @doc """
  This subscriber tests whether the hub allows subscriptions to be re-subscribed before they expire. The hub must allow a subscription to be re-activated, and must update the previous subscription based on the topic+callback pair, rather than creating a new subscription.
  """
  test "103 - Subscriber re-subscribes before the subscription expires", %{} do
  end

  @doc """
  This test will first subscribe to a topic, and will then send an unsubscription request. You will be able to test that the unsubscription is confirmed by seeing that a notification is not received when a new post is published.
  """
  test "104 - Unsubscribe request", %{} do
  end

  describe "105 - Plaintext content" do
    @doc """
    This test will check whether your hub can handle delivering content that is not HTML or XML. The content at the topic URL of this test is plaintext.
    """

    setup :setup_text_publisher

    test "105 - Plaintext content", %{
      subscriber_url: callback_url,
      publisher_url: topic_url
    } do
      assert {:ok, subscription} =
               Subscriptions.subscribe(
                 :rsscloud,
                 topic_url,
                 callback_url,
                 @subscription_lease_seconds
               )

      assert {:ok, update} = Updates.publish(topic_url)
      assert update.content_type == "text/plain"

      assert_enqueued(
        worker: Pleroma.Workers.DispatchFeedUpdateWorker,
        args: %{
          update_id: update.id,
          subscription_id: subscription.id,
          subscription_api: "rsscloud",
          callback_url: callback_url,
          secret: nil
        }
      )

      assert %{success: 1, failure: 0} = Oban.drain_queue(queue: :feed_updates)

      assert TeslaMockAgent.hits(:publisher) == 1
      assert TeslaMockAgent.hits(:subscriber) == 2

      [_challenge, publish] = TeslaMockAgent.access_list(:subscriber)
      assert publish.body == "url=" <> URI.encode_www_form(topic_url)

      assert Tesla.get_header(publish, "content-type") ==
               "application/x-www-form-urlencoded"
    end
  end

  describe "106 - JSON content" do
    @doc """
    This test will check whether your hub can handle delivering content that is not HTML or XML. The content at the topic URL of this test is JSON.
    """

    setup :setup_json_publisher

    test "106 - JSON content", %{
      subscriber_url: callback_url,
      publisher_url: topic_url
    } do
      assert {:ok, subscription} =
               Subscriptions.subscribe(
                 :rsscloud,
                 topic_url,
                 callback_url,
                 @subscription_lease_seconds
               )

      assert {:ok, update} = Updates.publish(topic_url)
      assert update.content_type == "application/json"

      assert_enqueued(
        worker: Pleroma.Workers.DispatchFeedUpdateWorker,
        args: %{
          update_id: update.id,
          subscription_id: subscription.id,
          subscription_api: "rsscloud",
          callback_url: callback_url,
          secret: nil
        }
      )

      assert %{success: 1, failure: 0} = Oban.drain_queue(queue: :feed_updates)

      assert TeslaMockAgent.hits(:publisher) == 1
      assert TeslaMockAgent.hits(:subscriber) == 2

      [_challenge, publish] = TeslaMockAgent.access_list(:subscriber)
      assert publish.body == "url=" <> URI.encode_www_form(topic_url)

      assert Tesla.get_header(publish, "content-type") ==
               "application/x-www-form-urlencoded"
    end
  end

  describe "XML content" do
    @doc """
    This test will check whether your hub can handle delivering content that is not HTML or XML. The content at the topic URL of this test is JSON.
    """

    setup :setup_xml_publisher

    test "XML content", %{
      subscriber_url: callback_url,
      publisher_url: topic_url
    } do
      assert {:ok, subscription} =
               Subscriptions.subscribe(
                 :rsscloud,
                 topic_url,
                 callback_url,
                 @subscription_lease_seconds
               )

      assert {:ok, update} = Updates.publish(topic_url)
      assert update.content_type == "application/rss+xml"

      assert_enqueued(
        worker: Pleroma.Workers.DispatchFeedUpdateWorker,
        args: %{
          update_id: update.id,
          subscription_id: subscription.id,
          subscription_api: "rsscloud",
          callback_url: callback_url,
          secret: nil
        }
      )

      assert %{success: 1, failure: 0} = Oban.drain_queue(queue: :feed_updates)

      assert TeslaMockAgent.hits(:publisher) == 1
      assert TeslaMockAgent.hits(:subscriber) == 2

      [_challenge, publish] = TeslaMockAgent.access_list(:subscriber)
      assert publish.body == "url=" <> URI.encode_www_form(topic_url)

      assert Tesla.get_header(publish, "content-type") ==
               "application/x-www-form-urlencoded"
    end
  end

  describe "pruning" do
    @doc """
    This test will check whether we can prune expired subscriptions.
    """

    setup :setup_xml_publisher

    test "after typical subscriber request", %{
      subscriber_url: callback_url,
      publisher_url: topic_url
    } do
      assert {:ok, subscription} =
               Subscriptions.subscribe(
                 :rsscloud,
                 topic_url,
                 callback_url,
                 @subscription_lease_seconds
               )

      assert {:ok, update} = Updates.publish(topic_url)
      assert update.content_type == "application/rss+xml"

      assert_enqueued(
        worker: Pleroma.Workers.DispatchFeedUpdateWorker,
        args: %{
          update_id: update.id,
          subscription_id: subscription.id,
          subscription_api: "rsscloud",
          callback_url: callback_url,
          secret: nil
        }
      )

      expiring =
        Subscriptions.from_now(1_000_000)
        |> DateTime.from_naive!("Etc/UTC")
        |> DateTime.to_iso8601()

      Pleroma.Workers.PruneFeedSubscriptionsWorker.new(%{expiring: expiring})
      |> Oban.insert()

      assert_enqueued(
        worker: Pleroma.Workers.PruneFeedSubscriptionsWorker,
        args: %{
          expiring: expiring
        }
      )

      assert %{success: 1, failure: 0} = Oban.drain_queue(queue: :prune_feed_subscriptions)
      assert %{success: 1, failure: 0} = Oban.drain_queue(queue: :feed_updates)
    end
  end

  def setup_html_publisher(_) do
    publisher_url = "http://localhost/publisher/posts"
    subscriber_url = "http://localhost/subscriber/callback"

    Tesla.Mock.mock(fn
      %{url: ^publisher_url} = req ->
        TeslaMockAgent.add_hit(:publisher, req)

        %Tesla.Env{
          status: 200,
          body: @html_body,
          headers: [
            {"content-type", "text/html; charset=UTF-8"}
          ]
        }

      %{url: ^subscriber_url} = req ->
        TeslaMockAgent.add_hit(:subscriber, req)

        %Tesla.Env{
          status: 200,
          body: "ok",
          headers: @content_type_text_plain
        }

      _not_matched ->
        %Tesla.Env{
          status: 404,
          body: "not found",
          headers: @content_type_text_plain
        }
    end)

    [publisher_url: publisher_url, subscriber_url: subscriber_url]
  end

  def setup_text_publisher(_) do
    publisher_url = "http://localhost/publisher/posts"
    subscriber_url = "http://localhost/subscriber/callback"

    Tesla.Mock.mock(fn
      %{url: ^publisher_url} = req ->
        TeslaMockAgent.add_hit(:publisher, req)

        %Tesla.Env{
          status: 200,
          body: @text_body,
          headers: @content_type_text_plain
        }

      %{url: ^subscriber_url} = req ->
        TeslaMockAgent.add_hit(:subscriber, req)

        %Tesla.Env{
          status: 200,
          body: "ok",
          headers: @content_type_text_plain
        }

      _not_matched ->
        %Tesla.Env{
          status: 404,
          body: "not found",
          headers: @content_type_text_plain
        }
    end)

    [publisher_url: publisher_url, subscriber_url: subscriber_url]
  end

  def setup_json_publisher(_) do
    publisher_url = "http://localhost/publisher/posts"
    subscriber_url = "http://localhost/subscriber/callback"

    Tesla.Mock.mock(fn
      %{url: ^publisher_url} = req ->
        TeslaMockAgent.add_hit(:publisher, req)

        %Tesla.Env{
          status: 200,
          body: Jason.encode!(@json_body),
          headers: [
            {"content-type", "application/json"}
          ]
        }

      %{url: ^subscriber_url} = req ->
        TeslaMockAgent.add_hit(:subscriber, req)

        %Tesla.Env{
          status: 200,
          body: "ok",
          headers: @content_type_text_plain
        }

      _not_matched ->
        %Tesla.Env{
          status: 404,
          body: "not found",
          headers: @content_type_text_plain
        }
    end)

    [publisher_url: publisher_url, subscriber_url: subscriber_url]
  end

  def setup_xml_publisher(_) do
    publisher_url = "http://localhost/publisher/posts"
    subscriber_url = "http://localhost/subscriber/callback"

    Tesla.Mock.mock(fn
      %{url: ^publisher_url} = req ->
        TeslaMockAgent.add_hit(:publisher, req)

        %Tesla.Env{
          status: 200,
          body: @xml_body,
          headers: [
            {"content-type", "application/rss+xml"}
          ]
        }

      %{url: ^subscriber_url} = req ->
        TeslaMockAgent.add_hit(:subscriber, req)

        %Tesla.Env{
          status: 200,
          body: "ok",
          headers: @content_type_text_plain
        }

      _not_matched ->
        %Tesla.Env{
          status: 404,
          body: "not found",
          headers: @content_type_text_plain
        }
    end)

    [publisher_url: publisher_url, subscriber_url: subscriber_url]
  end
end
