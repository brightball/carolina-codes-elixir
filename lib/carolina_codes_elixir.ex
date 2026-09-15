defmodule CarolinaCodesElixir do
  @moduledoc false

  def language, do: "Elixir"
  def language_version, do: System.version()
  def api_version, do: "0.2.0"
  def framework, do: "Phoenix"
  def created_year, do: 2026
  def schema_version, do: 1

  def listen_host, do: "::"

  def listen_ip, do: {0, 0, 0, 0, 0, 0, 0, 0}

  def endpoints do
    [
      %{"method" => "GET", "path" => "/", "query" => []},
      %{"method" => "GET", "path" => "/health", "query" => []},
      %{"method" => "GET", "path" => "/v1/years", "query" => []},
      %{"method" => "GET", "path" => "/v1/speakers", "query" => ["year"]},
      %{"method" => "GET", "path" => "/v1/speakers/:slug", "query" => []},
      %{"method" => "GET", "path" => "/v1/speakers/:year/:slug", "query" => []},
      %{"method" => "GET", "path" => "/v1/sponsors", "query" => ["year"]},
      %{"method" => "GET", "path" => "/v1/sponsors/:slug", "query" => []},
      %{"method" => "GET", "path" => "/v1/sponsors/:year/:slug", "query" => []}
    ]
  end

  def identity do
    %{
      "language" => language(),
      "language_version" => language_version(),
      "api_version" => api_version(),
      "framework" => framework(),
      "created_year" => created_year(),
      "schema_version" => schema_version(),
      "endpoints" => endpoints()
    }
  end
end
