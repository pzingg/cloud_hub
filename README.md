# cloud_hub

**cloud_hub** is an update notification hub server that implements two APIs
that are typically used to enable near-realtime updates for subscribers of
RSS and Atom feeds.

* For RSS 2.0 publishers, the server exposes the compliant "http-rest" and
  "https-rest" protocols of the [RSSCloud API](https://www.rssboard.org/rsscloud-interface). The "xml-rpc" protocol is not implemented at present,
  but could be added if there is interest.

* For Atom publishers, the server exposes the
  [WebSub Hub API](https://www.w3.org/TR/websub/).

The two APIs share much in common, and are used to distribute notifications of
live changes from various publishers.

## RssCloud Configuration

The RssCloud API exposes two HTTP **POST** URLs, per the spec:

* The **/rsscloud/pleaseNotify** URL is used by an interested subscriber to request
realtime updates to a given resource.

* The **/rsscloud/ping** URL is used by a publisher to inform the hub of an
update to a resource. If any subscribers have requested updates for the
resource, they are notified by an HTTP POST callback.

If you are a subscriber, please see the
[RSSCloud API docs](https://www.rssboard.org/rsscloud-interface) or Dave Winer's
[RSS Cloud Walkthrough article](https://rsscloud.org/walkthrough/)
for more information on the www-form-urlencoded parameters that should
be sent to these URLs, and for how the hub server will request validation and
send notification callbacks.

If you the publisher of an RSS 2.0 feed, you can add a **\<cloud\>** child element
to the **\<channel\>** element in your feed, with these attributes:

* **protocol** set to "http-rest" or "https-rest" depending on the endpoint URL
for your cloud_hub deployment.
* **domain** set to the host name of the endpoint URL
for your cloud_hub deployment.
* **port** set to the TCP port of the endpoint URL of your cloud_hub deployment.
* **path** set to "/rsscloud/pleaseNotify"
* **registerProcedure** set to "" (XML-RPC is not implemented)

See the [RSS 2.0 Specification](https://www.rssboard.org/rss-specification#ltcloudgtSubelementOfLtchannelgt)
for more information about the **\<cloud\>** element.

Then whenever you update your feed (the "resource"), send a HTTP POST request
to the **/rsscloud/ping** URL on the cloud_hub server with one
www-form-urlencoded parameter:

* **url**, with a value set to the the URL that the cloud_hub server will use to
fetch the updated resource.

After the post to **/rsscloud/ping**, any subscribers who are subcribed to
the URL will be notified via an asynchronous callback.

## WebSub Hub Configuration

The WebSub Hub API exposes one HTTP **POST** URL, at **/hub**.

* When sent a www-form-urlencoded parameter **"hub.mode"** with a value of
either **"subscribe"** or **"unsubscribe"**, this URL is used by subscribers to request
realtime updates or to cancel previously established subscriptions, respectively.

* After a publisher updates a resource, it sends a **"hub.mode"** parameter with
a value of **"publish"** to the **/hub** URL. If any subscribers have requested
updates for the resource, they receive the updated contents via an asynchronous
HTTP POST callback.

If you are a subscriber, please see
[Section 5](https://www.w3.org/TR/websub/#subscribing-and-unsubscribing)
of the WebSub Hub specification for information on the parameters that must
be sent in the POST body to the **/hub** URL.

If you are the publisher of an Atom feed, your feed should include at
least two **\<link\>** elements as children of the **\<feed\>** element.

* A **\<link\>** with a **rel** attribute having the value **"self"**. The
**href** attribute should be the URL that the WebSub Hub server will
use to fetch resource content when it has been updated.

* A **\<link\>** with a **rel** attribute having the value **"hub"**. The
**href** attribute should be the URL of your cloud_hub deployment
(with the path component of the URL being "/hub").

Then whenever you update your feed (the "resource"), send a HTTP POST request
to the **/hub** URL on the cloud_hub server with two www-form-urlencoded parameters:

* **hub.mode**, with a value of **"publish"**.

* **hub.topic**, with a value set to the the URL that the cloud_hub server will use to
fetch the updated resource.

## Admin Monitoring

The **/status** URL uses Phoenix LiveView to provide a dashboard of the
hub's activity. At present, this is exposed publicly.

## TODO

See the issues list at https://github.com/pzingg/cloud_sub/issues, and
feel free to note bugs.

## Development

You can setup your own development / production environment of cloud_hub as
with any normal Elixir / Phoenix development.

  * Clone this repository.
  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [localhost:4000](http://localhost:4000) from your browser.

Ready to run in production? Please
[check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Acknowledgments

This repository is forked from the original
[WebSubHub repository](https://github.com/clone1018/WebSubHub) by Luke Strickland.
Work to extend the server to support RSSCloud, and other changes made for future
compatibility with the Mastodon-compatible
[Akkoma Fediverse microblogging server](https://akkoma.dev/AkkomaGang/akkoma/)
are by Peter Zingg.

### Contributing

1. [Fork it!](https://github.com/pzingg/cloud_hub)
2. Create your feature branch (`git checkout -b feature/my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-new-feature`)
5. Create new Pull Request

## Testing

The project includes a comprehensive test suite, so you should be encouraged to run tests as frequently as possible.

```sh
mix test
```

## Help

If you need help with anything, please feel free to open a GitHub issue
[at the original WebSubHub repository](https://github.com/clone1018/WebSubHub/issues) or [at the combined WebSub Hub and RSS Cloud repository](https://github.com/pzingg/cloud_sub/issues).

## License

cloud_sub is licensed under the [MIT License](LICENSE.md).
