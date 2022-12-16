defmodule Pleroma.Feed.Subscriptions do
  @moduledoc """
  The Subscriptions context.
  """
  require Logger

  import Ecto.Query, warn: false
  alias CloudHub.Repo
  alias Pleroma.HTTP

  alias Pleroma.Feed.Subscription
  alias Pleroma.Feed.Topic

  def subscribe(api, topic_url, callback_url, lease_seconds \\ 864_000, opts \\ []) do
    with {:ok, _} <- validate_url(topic_url),
         {:ok, _callback_uri} <- validate_url(callback_url),
         {:ok, topic} <- find_or_create_topic(topic_url),
         :ok <- validate_subscription(api, topic, callback_url, lease_seconds, opts) do
      find_or_create_subscription(api, topic, callback_url, lease_seconds, opts)
    else
      {:subscribe_validation_error, reason} ->
        # WebSub must notify callback on failure. Ignore return value.
        # RSSCloud just returns an error to the caller.
        _ = deny_subscription(api, callback_url, topic_url, reason)
        {:error, reason}

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("subscribe data error: #{inspect(changeset.errors)}")
        {:error, "data error"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def unsubscribe(topic_url, callback_url) do
    with {:ok, _} <- validate_url(topic_url),
         {:ok, callback_uri} <- validate_url(callback_url),
         %Topic{} = topic <- get_topic_by_url(topic_url),
         %Subscription{api: api} = subscription <-
           Repo.get_by(Subscription, topic_id: topic.id, callback_url: callback_url) do
      if api == :websub do
        _ = validate_unsubscribe(topic, callback_uri)
      end

      subscription
      |> Subscription.changeset(%{
        expires_at: NaiveDateTime.utc_now()
      })
      |> Repo.update()
    else
      _ -> {:error, :subscription_not_found}
    end
  end

  @doc """
  We callback on WebSub subscriptions just before deleting them.
  """
  def final_unsubscribe(%Subscription{api: :websub} = subscription) do
    with {:ok, callback_uri} <- validate_url(subscription.callback_url) do
      validate_unsubscribe(subscription.topic, callback_uri)
    else
      _ ->
        {:unsubscribe_validation_error, "Subscription with improper callback_url"}
    end
  end

  def final_unsubscribe(%Subscription{api: :rsscloud}), do: :ok

  def get_topic_by_url(topic_url) do
    Repo.get_by(Topic, url: topic_url)
  end

  @doc """
  Find or create a topic.

  Topics can exist without any valid subscriptions. Additionally a subscription can fail to validate and a topic still exist.

  ## Examples

      iex> find_or_create_topic("https://some-topic-url")
      {:ok, %Topic{}}
  """
  def find_or_create_topic(topic_url) do
    case Repo.get_by(Topic, url: topic_url) do
      %Topic{} = topic ->
        {:ok, topic}

      nil ->
        %Topic{}
        |> Topic.changeset(%{
          url: topic_url,
          expires_at: ~N[2046-12-31 23:59:00]
        })
        |> Repo.insert()
    end
  end

  def find_subscription_by_api_topic_and_url(api, %Topic{} = topic, callback_url) do
    Repo.get_by(Subscription, api: api, topic_id: topic.id, callback_url: callback_url)
  end

  def find_or_create_subscription(api, %Topic{} = topic, callback_url, lease_seconds, opts) do
    # BACKPORT api: api
    case Repo.get_by(Subscription, api: api, topic_id: topic.id, callback_url: callback_url) do
      %Subscription{} = subscription ->
        lease_seconds = convert_lease_seconds(lease_seconds)
        expires_at = NaiveDateTime.add(NaiveDateTime.utc_now(), lease_seconds, :second)

        subscription
        |> Subscription.changeset(%{
          secret: Keyword.get(opts, :secret),
          diff_domain: Keyword.get(opts, :diff_domain, false),
          expires_at: expires_at,
          lease_seconds: lease_seconds
        })
        |> Repo.update()

      nil ->
        create_subscription(api, topic, callback_url, lease_seconds, opts)
    end
  end

  @doc """
  Validate a WebSub subscription by sending a HTTP GET to the subscriber's callback_url.
  Validate an RSSCloud subscription by sending a HTTP GET or POST to the subscriber's callback_url.
  """
  def validate_subscription(
        :websub,
        %Topic{} = topic,
        callback_url,
        lease_seconds,
        _opts
      ) do
    challenge = :crypto.strong_rand_bytes(32) |> Base.url_encode64() |> binary_part(0, 32)

    query = [
      {"hub.mode", "subscribe"},
      {"hub.topic", topic.url},
      {"hub.challenge", challenge},
      {"hub.lease_seconds", lease_seconds}
    ]

    case HTTP.get(callback_url, [], query: query) do
      {:ok, %Tesla.Env{status: code, body: body}} when code >= 200 and code < 300 ->
        # Ensure the response body matches our challenge
        if challenge != String.trim(body) do
          {:subscribe_validation_error, :failed_challenge_body}
        else
          :ok
        end

      other ->
        handle_validation_errors(other)
    end
  end

  def validate_subscription(
        :rsscloud,
        %Topic{} = topic,
        callback_url,
        _lease_seconds,
        opts
      ) do
    diff_domain = Keyword.get(opts, :diff_domain, false)
    validate_rsscloud_subscription(topic, callback_url, diff_domain)
  end

  def validate_rsscloud_subscription(topic, callback_url, true) do
    challenge = :crypto.strong_rand_bytes(32) |> Base.url_encode64() |> binary_part(0, 32)

    query = [
      {"url", topic.url},
      {"challenge", challenge}
    ]

    case HTTP.get(callback_url, [], query: query) do
      {:ok, %Tesla.Env{status: code, body: body}} when code >= 200 and code < 300 ->
        # Ensure the response body contains our challenge
        if String.contains?(body, challenge) do
          :ok
        else
          {:subscribe_validation_error, :failed_challenge_body}
        end

      other ->
        handle_validation_errors(other)
    end
  end

  def validate_rsscloud_subscription(topic, callback_uri, false) do
    callback_url = to_string(callback_uri)
    body = %{url: topic.url}

    case HTTP.post_form(callback_url, body) do
      {:ok, %Tesla.Env{status: code}} when code >= 200 and code < 300 ->
        :ok

      other ->
        handle_validation_errors(other)
    end
  end

  def handle_validation_errors({:ok, %Tesla.Env{status: 404}}) do
    {:subscribe_validation_error, :failed_404_response}
  end

  def handle_validation_errors({:ok, %Tesla.Env{} = env}) do
    Logger.error("failed_unknown_response #{inspect(env)}")
    {:subscribe_validation_error, :failed_unknown_response}
  end

  def handle_validation_errors({:error, :invalid_request}) do
    {:subscribe_validation_error, :invalid_request}
  end

  def handle_validation_errors({:error, reason}) do
    Logger.error("Got unexpected error from validate subscription call: #{reason}")
    {:subscribe_validation_error, :failed_unknown_error}
  end

  @doc """
  Validate a WebSub unsubscription by sending a HTTP GET to the subscriber's callback_url.
  """
  def validate_unsubscribe(
        %Topic{} = topic,
        %URI{} = callback_uri
      ) do
    challenge = :crypto.strong_rand_bytes(32) |> Base.url_encode64() |> binary_part(0, 32)

    query = [
      {"hub.mode", "unsubscribe"},
      {"hub.topic", topic.url},
      {"hub.challenge", challenge}
    ]

    callback_url = to_string(callback_uri)

    case HTTP.get(callback_url, [], query: query) do
      {:ok, %Tesla.Env{}} ->
        :ok

      {:error, reason} ->
        Logger.error("Got unexpected error from validate unsubscribe call: #{reason}")
        {:unsubscribe_validation_error, :failed_unknown_error}
    end
  end

  def create_subscription(api, %Topic{} = topic, callback_url, lease_seconds, opts) do
    lease_seconds = convert_lease_seconds(lease_seconds)
    expires_at = NaiveDateTime.add(NaiveDateTime.utc_now(), lease_seconds, :second)

    # BACKPORT
    %Subscription{
      topic_id: topic.id
    }
    |> Subscription.changeset(%{
      api: api,
      callback_url: callback_url,
      lease_seconds: lease_seconds,
      expires_at: expires_at,
      diff_domain: Keyword.get(opts, :diff_domain, false),
      secret: Keyword.get(opts, :secret)
    })
    |> Repo.insert()
  end

  defp convert_lease_seconds(seconds) when is_binary(seconds) do
    String.to_integer(seconds)
  end

  defp convert_lease_seconds(seconds), do: seconds

  def deny_subscription(:websub, callback_url, topic_url, reason) do
    # If (and when) the subscription is denied, the hub MUST inform the subscriber by sending an HTTP [RFC7231]
    # (or HTTPS [RFC2818]) GET request to the subscriber's callback URL as given in the subscription request. This request has the following query string arguments appended (format described in Section 4 of [URL]):
    with {:ok, callback_uri} <- validate_url(callback_url) do
      query = [
        {"hub.mode", "denied"},
        {"hub.topic", topic_url},
        {"hub.reason", reason_string(reason)}
      ]

      final_url = to_string(callback_uri)

      # We don't especially care about a response on this one
      case HTTP.get(final_url, [], query: query) do
        {:ok, %Tesla.Env{}} ->
          :ok

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  def deny_subscription(:rsscloud, _callback_url, _topic_url, _reason), do: :ok

  def reason_string(reason) when is_binary(reason), do: reason
  def reason_string(reason) when is_atom(reason), do: Atom.to_string(reason)
  def reason_string(reason), do: IO.inspect(reason)

  def list_active_topic_subscriptions(%Topic{} = topic) do
    now = NaiveDateTime.utc_now()

    from(s in Subscription,
      where: s.topic_id == ^topic.id and s.expires_at >= ^now
    )
    |> Repo.all()
  end

  def list_inactive_subscriptions(now) do
    from(s in Subscription,
      where: s.expires_at < ^now,
      join: t in assoc(s, :topic),
      preload: [topic: t]
    )
    |> Repo.all()
  end

  def delete_subscription(subscription, now \\ nil) do
    now = now || NaiveDateTime.utc_now()

    Repo.transaction(fn ->
      topic_id = subscription.topic_id

      case Repo.delete(subscription) do
        {:ok, _} ->
          {n_topics, topic_ids} = update_topic_expirations([topic_id], now)
          {1, n_topics, topic_ids}

        _ ->
          {0, 0, []}
      end
    end)
    |> case do
      {:ok, res} -> res
      {:error, reason} -> {:error, reason}
    end
  end

  # BACKPORT
  def delete_all_inactive_subscriptions(now) do
    Repo.transaction(fn ->
      # Cascades to delete all SubscriptionUpdates as well
      {n_subs, topic_ids} =
        from(s in Subscription,
          select: s.topic_id,
          where: s.expires_at < ^now
        )
        |> Repo.delete_all()

      # Update those topics who now don't have a subscription
      {n_topics, topic_ids} = update_topic_expirations(topic_ids, now)

      {n_subs, n_topics, topic_ids}
    end)
    |> case do
      {:ok, res} -> res
      {:error, reason} -> {:error, reason}
    end
  end

  def update_topic_expirations(topic_ids, now \\ nil) do
    now = now || NaiveDateTime.utc_now()
    lease_seconds = 6 * 3_600
    expires_at = NaiveDateTime.add(now, lease_seconds, :second)

    from(t in Topic,
      select: t.id,
      where: not exists(from(s in Subscription, where: s.topic_id in ^topic_ids)),
      update: [set: [updated_at: fragment("NOW()"), expires_at: ^expires_at]]
    )
    |> Repo.update_all([])
  end

  defp validate_url(url) when is_binary(url) do
    case URI.new(url) do
      {:ok, uri} ->
        if uri.scheme in ["http", "https"] do
          {:ok, uri}
        else
          {:error, :url_not_http}
        end

      err ->
        err
    end
  end

  defp validate_url(_), do: {:error, :url_not_binary}

  def count_topics do
    Repo.one(
      from(u in Topic,
        select: count(u.id)
      )
    )
  end

  def count_active_subscriptions do
    now = NaiveDateTime.utc_now()

    Repo.one(
      from(s in Subscription,
        where: s.expires_at >= ^now,
        select: count(s.id)
      )
    )
  end

  def subscription_updates_chart do
    case Repo.query("""
         select date(pushed_at) as "date", count(*) as "count"
         from subscription_updates
         group by date(pushed_at)
         order by date(pushed_at) desc
         limit 30;
         """) do
      {:ok, %Postgrex.Result{rows: rows}} ->
        flipped = Enum.reverse(rows)

        %{
          keys: Enum.map(flipped, fn [key, _] -> key end),
          values: Enum.map(flipped, fn [_, value] -> value end)
        }

      _ ->
        %{keys: [], values: []}
    end
  end
end
