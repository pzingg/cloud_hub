defmodule CloudHub.Repo do
  use Ecto.Repo,
    otp_app: :cloud_hub,
    adapter: Ecto.Adapters.Postgres
end
