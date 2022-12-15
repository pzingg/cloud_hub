ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(CloudHub.Repo, :manual)

{:ok, _} = Application.ensure_all_started(:fake_server)
