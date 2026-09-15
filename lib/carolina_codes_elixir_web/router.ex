defmodule CarolinaCodesElixirWeb.Router do
  use CarolinaCodesElixirWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug CarolinaCodesElixirWeb.Plugs.PolyglotHeaders
  end

  scope "/", CarolinaCodesElixirWeb do
    pipe_through :api

    get "/", IdentityController, :show
    get "/health", HealthController, :show

    get "/v1/years", CatalogController, :years
    get "/v1/speakers", CatalogController, :speakers
    get "/v1/speakers/:year/:slug", CatalogController, :speaker_year
    get "/v1/speakers/:slug", CatalogController, :speaker
    get "/v1/sponsors", CatalogController, :sponsors
    get "/v1/sponsors/:year/:slug", CatalogController, :sponsor_year
    get "/v1/sponsors/:slug", CatalogController, :sponsor
  end
end
