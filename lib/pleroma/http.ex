defmodule Pleroma.HTTP do
  def get(url, headers \\ [], options \\ [])

  def get(url, [], options) do
    {query, options} = Keyword.pop(options, :params, [])
    client() |> Tesla.get(url, Keyword.put(options, :query, query))
  end

  def get(url, headers, options) when is_list(headers) do
    {query, options} =
      options
      |> Keyword.put(:headers, headers)
      |> Keyword.pop(:params, [])

    client() |> Tesla.get(url, Keyword.put(options, :query, query))
  end

  def post(url, body, headers \\ [])

  def post(url, body, []) do
    client() |> Tesla.post(url, body)
  end

  def post(url, body, headers) when is_list(headers) do
    client() |> Tesla.post(url, body, headers: headers)
  end

  defp client() do
    Tesla.client([
      Tesla.Middleware.FollowRedirects,
      Tesla.Middleware.KeepRequest
    ])
  end
end
