defmodule Pleroma.Feed.UpdatesTest do
  use CloudHub.DataCase
  use Oban.Testing, repo: CloudHub.Repo

  require Logger

  alias Pleroma.Feed.Updates
  alias Pleroma.Feed.Subscriptions

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

  setup do
    [subscriber_url: "http://localhost/subscriber/callback"]
  end

  describe "updates" do
    test "publishing update dispatches jobs", %{
      subscriber_url: callback_url
    } do
      topic_url = "https://localhost/publisher/topic/123"

      Tesla.Mock.mock(fn
        %{url: ^topic_url} = req ->
          TeslaMockAgent.add_hit(:publisher, req)

          %Tesla.Env{
            status: 200,
            body: @html_body,
            headers: [
              {"content-type", "text/html; charset=UTF-8"}
            ]
          }

        %{method: :get, url: ^callback_url, query: query} = req ->
          TeslaMockAgent.add_hit(:subscriber, req)

          query = Map.new(query)

          if Map.has_key?(query, "hub.challenge") do
            %Tesla.Env{
              status: 200,
              body: Map.get(query, "hub.challenge"),
              headers: @content_type_text_plain
            }
          else
            %Tesla.Env{status: 400, body: "no challenge", headers: @content_type_text_plain}
          end

        not_matched ->
          Logger.error("not matched #{not_matched.url}")

          %Tesla.Env{
            status: 404,
            body: "not found",
            headers: @content_type_text_plain
          }
      end)

      assert {:ok, _} = Subscriptions.subscribe(:websub, topic_url, callback_url)
      assert {:ok, update} = Updates.publish(topic_url)

      assert TeslaMockAgent.hits(:subscriber) == 1

      assert [job] = all_enqueued(worker: Pleroma.Workers.DispatchFeedUpdateWorker)
      assert job.args["update_id"] == update.id
      assert job.args["callback_url"] == callback_url
    end
  end
end
