defmodule TeslaMockAgent do
  @moduledoc false

  require Logger

  def init() do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def stop() do
    # Agent.stop(__MODULE__)
  end

  def add_hit(key, env) do
    Agent.update(__MODULE__, fn state -> [{key, env} | state] end)
  end

  def access_list(key) do
    Agent.get(__MODULE__, fn state ->
      Enum.filter(state, fn {k, _v} -> k == key end)
      |> Enum.map(fn {_k, v} -> v end)
      |> Enum.reverse()
    end)
  end

  def hits(key) do
    access_list(key)
    |> Enum.count()
  end
end
