defmodule Pleroma.Feed.RSSCloudTest do
  use CloudHub.DataCase
  use Oban.Testing, repo: CloudHub.Repo

  alias CloudHub.HTTPClient

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

    setup [:setup_html_publisher, :setup_subscriber]

    test "100 - Typical subscriber request", %{
      subscriber_pid: subscriber_pid,
      subscriber_url: subscriber_url,
      publisher_pid: publisher_pid,
      publisher_url: publisher_url
    } do
      topic_url = publisher_url
      callback_url = subscriber_url
      {:ok, subscription} = Subscriptions.subscribe(:rsscloud, topic_url, callback_url)

      {:ok, update} = Updates.publish(topic_url)
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

      assert hits(publisher_pid) == 1
      assert hits(subscriber_pid) == 2
      {:ok, [_challenge, publish]} = FakeServer.Instance.access_list(subscriber_pid)

      assert publish.body == "url=" <> URI.encode_www_form(topic_url)

      assert HTTPClient.get_header(publish.headers, "content-type") ==
               "application/x-www-form-urlencoded"
    end

    test "does not get publish if already unsubscribed", %{
      subscriber_pid: subscriber_pid,
      subscriber_url: subscriber_url,
      publisher_pid: publisher_pid,
      publisher_url: publisher_url
    } do
      topic_url = publisher_url
      callback_url = subscriber_url
      {:ok, subscription} = Subscriptions.subscribe(:rsscloud, topic_url, callback_url)

      {:ok, _} = Subscriptions.unsubscribe(topic_url, callback_url)

      # Quick sleep
      :timer.sleep(1000)

      {:ok, update} = Updates.publish(topic_url)

      refute_enqueued(
        worker: Pleroma.Workers.DispatchFeedUpdateWorker,
        args: %{
          update_id: update.id,
          subscription_id: subscription.id,
          callback_url: callback_url,
          secret: nil
        }
      )

      assert hits(publisher_pid) == 1

      # Note that :rsscloud does not notify on unsubscription
      assert hits(subscriber_pid) == 1
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

    setup [:setup_text_publisher, :setup_subscriber]

    test "105 - Plaintext content", %{
      subscriber_pid: subscriber_pid,
      subscriber_url: subscriber_url,
      publisher_pid: publisher_pid,
      publisher_url: publisher_url
    } do
      topic_url = publisher_url
      callback_url = subscriber_url
      {:ok, subscription} = Subscriptions.subscribe(:rsscloud, topic_url, callback_url)

      {:ok, update} = Updates.publish(topic_url)
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

      assert hits(publisher_pid) == 1
      assert hits(subscriber_pid) == 2
      {:ok, [_challenge, publish]} = FakeServer.Instance.access_list(subscriber_pid)

      assert publish.body == "url=" <> URI.encode_www_form(topic_url)

      assert HTTPClient.get_header(publish.headers, "content-type") ==
               "application/x-www-form-urlencoded"
    end
  end

  describe "106 - JSON content" do
    @doc """
    This test will check whether your hub can handle delivering content that is not HTML or XML. The content at the topic URL of this test is JSON.
    """

    setup [:setup_json_publisher, :setup_subscriber]

    test "106 - JSON content", %{
      subscriber_pid: subscriber_pid,
      subscriber_url: subscriber_url,
      publisher_pid: publisher_pid,
      publisher_url: publisher_url
    } do
      topic_url = publisher_url
      callback_url = subscriber_url
      {:ok, subscription} = Subscriptions.subscribe(:rsscloud, topic_url, callback_url)

      {:ok, update} = Updates.publish(topic_url)
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

      assert hits(publisher_pid) == 1
      assert hits(subscriber_pid) == 2
      {:ok, [_challenge, publish]} = FakeServer.Instance.access_list(subscriber_pid)

      assert publish.body == "url=" <> URI.encode_www_form(topic_url)

      assert HTTPClient.get_header(publish.headers, "content-type") ==
               "application/x-www-form-urlencoded"
    end
  end

  describe "XML content" do
    @doc """
    This test will check whether your hub can handle delivering content that is not HTML or XML. The content at the topic URL of this test is JSON.
    """

    setup [:setup_xml_publisher, :setup_subscriber]

    test "XML content", %{
      subscriber_pid: subscriber_pid,
      subscriber_url: subscriber_url,
      publisher_pid: publisher_pid,
      publisher_url: publisher_url
    } do
      topic_url = publisher_url
      callback_url = subscriber_url
      {:ok, subscription} = Subscriptions.subscribe(:rsscloud, topic_url, callback_url)

      {:ok, update} = Updates.publish(topic_url)
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

      assert hits(publisher_pid) == 1
      assert hits(subscriber_pid) == 2
      {:ok, [_challenge, publish]} = FakeServer.Instance.access_list(subscriber_pid)

      assert publish.body == "url=" <> URI.encode_www_form(topic_url)

      assert HTTPClient.get_header(publish.headers, "content-type") ==
               "application/x-www-form-urlencoded"
    end
  end

  describe "pruning" do
    @doc """
    This test will check whether we can prune expired subscriptions.
    """

    setup [:setup_xml_publisher, :setup_subscriber]

    test "Typical subscriber request", %{
      subscriber_pid: _subscriber_pid,
      subscriber_url: subscriber_url,
      publisher_pid: _publisher_pid,
      publisher_url: publisher_url
    } do
      topic_url = publisher_url
      callback_url = subscriber_url
      {:ok, subscription} = Subscriptions.subscribe(:rsscloud, topic_url, callback_url)

      {:ok, update} = Updates.publish(topic_url)
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
        DateTime.utc_now()
        |> DateTime.add(30 * 24 * 3_600, :second)
        |> DateTime.to_iso8601()

      Pleroma.Workers.PruneFeedSubscriptionsWorker.new(%{expiring: expiring})
      |> Oban.insert()

      assert_enqueued(
        worker: Pleroma.Workers.PruneFeedSubscriptionsWorker,
        args: %{
          expiring: expiring
        }
      )

      assert %{success: 1, failure: 0} = Oban.drain_queue(queue: :prune_subscriptions)
      assert %{success: 1, failure: 0} = Oban.drain_queue(queue: :feed_updates)
    end
  end

  def setup_html_publisher(_) do
    {:ok, pid} = FakeServer.start(:publisher_server)
    port = FakeServer.port!(pid)

    on_exit(fn ->
      FakeServer.stop(pid)
    end)

    callback_path = "/posts"
    publisher_url = "http://localhost:#{port}" <> callback_path

    :ok =
      FakeServer.put_route(pid, callback_path, fn _ ->
        FakeServer.Response.ok(
          @html_body,
          %{
            "Content-Type" => "text/html; charset=UTF-8"
          }
        )
      end)

    [publisher_pid: pid, publisher_url: publisher_url]
  end

  def setup_text_publisher(_) do
    {:ok, pid} = FakeServer.start(:publisher_server)
    port = FakeServer.port!(pid)

    on_exit(fn ->
      FakeServer.stop(pid)
    end)

    callback_path = "/posts"
    publisher_url = "http://localhost:#{port}" <> callback_path

    :ok =
      FakeServer.put_route(pid, callback_path, fn _ ->
        FakeServer.Response.ok(
          @text_body,
          %{"Content-Type" => "text/plain"}
        )
      end)

    [publisher_pid: pid, publisher_url: publisher_url]
  end

  def setup_json_publisher(_) do
    {:ok, pid} = FakeServer.start(:publisher_server)
    port = FakeServer.port!(pid)

    on_exit(fn ->
      FakeServer.stop(pid)
    end)

    callback_path = "/posts"
    publisher_url = "http://localhost:#{port}" <> callback_path

    :ok =
      FakeServer.put_route(pid, callback_path, fn _ ->
        FakeServer.Response.ok(
          @json_body,
          %{"Content-Type" => "application/json"}
        )
      end)

    [publisher_pid: pid, publisher_url: publisher_url]
  end

  def setup_xml_publisher(_) do
    {:ok, pid} = FakeServer.start(:publisher_server)
    port = FakeServer.port!(pid)

    on_exit(fn ->
      FakeServer.stop(pid)
    end)

    callback_path = "/posts"
    publisher_url = "http://localhost:#{port}" <> callback_path

    :ok =
      FakeServer.put_route(pid, callback_path, fn _ ->
        FakeServer.Response.ok(
          @xml_body,
          %{"Content-Type" => "application/rss+xml"}
        )
      end)

    [publisher_pid: pid, publisher_url: publisher_url]
  end

  def setup_subscriber(_) do
    {:ok, pid} = FakeServer.start(:subscriber_server)
    port = FakeServer.port!(pid)

    on_exit(fn ->
      FakeServer.stop(pid)
    end)

    callback_path = "/callback"
    subscriber_url = "http://localhost:#{port}" <> callback_path

    headers = %{"Content-Type" => "text/plain"}

    :ok =
      FakeServer.put_route(pid, callback_path, fn
        %FakeServer.Request{} ->
          FakeServer.Response.ok("ok", headers)
      end)

    [subscriber_pid: pid, subscriber_url: subscriber_url]
  end

  defp hits(subscriber_pid) do
    case FakeServer.Instance.access_list(subscriber_pid) do
      {:ok, access_list} -> length(access_list)
      {:error, _reason} -> 0
    end
  end
end
