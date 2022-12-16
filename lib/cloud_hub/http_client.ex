defmodule CloudHub.HTTPClient do
  def get(url, opts \\ []) do
    simple_client() |> Tesla.get(url, opts)
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
    Tesla.client([
      Tesla.Middleware.FollowRedirects,
      Tesla.Middleware.KeepRequest
    ])
  end

  def form_client() do
    Tesla.client([
      Tesla.Middleware.FollowRedirects,
      Tesla.Middleware.KeepRequest,
      Tesla.Middleware.FormUrlencoded
    ])
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
