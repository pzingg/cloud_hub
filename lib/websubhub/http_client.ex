defmodule WebSubHub.HTTPClient do
  def get(url, query \\ nil)

  def get(url, nil) do
    simple_client() |> Tesla.get(url)
  end

  def get(url, query) when is_map(query) do
    simple_client() |> Tesla.get(url, query: query)
  end

  def post(url, body, headers \\ [])

  def post(url, body, []) do
    client() |> Tesla.post(url, body)
  end

  def post(url, body, headers) when is_list(headers) do
    client() |> Tesla.post(url, body, headers: headers)
  end

  def post_form(url, body, headers \\ [])

  def post_form(url, body, []) do
    form_client() |> Tesla.post(url, body)
  end

  def post_form(url, body, headers) when is_list(headers) do
    form_client() |> Tesla.post(url, body, headers: headers)
  end

  def simple_client() do
    Tesla.client(
      [
        Tesla.Middleware.FollowRedirects,
        Tesla.Middleware.KeepRequest
      ],
      {Tesla.Adapter.Finch, name: MyFinch, recv_timeout: 4_000}
    )
  end

  def form_client() do
    Tesla.client(
      [
        Tesla.Middleware.FollowRedirects,
        Tesla.Middleware.KeepRequest,
        Tesla.Middleware.FormUrlencoded
      ],
      {Tesla.Adapter.Finch, name: MyFinch, recv_timeout: 4_000}
    )
  end

  def client() do
    Tesla.client([
      Tesla.Middleware.FollowRedirects,
      Tesla.Middleware.KeepRequest,
      Tesla.Middleware.JSON
    ])
  end

  def get_header(headers, key, default \\ nil) do
    key = String.downcase(key)
    matching? = &(String.downcase(&1) == key)
    found = for {k, v} <- headers, matching?.(k), do: v

    case found do
      [value] ->
        value

      _ ->
        default
    end
  end
end
