defmodule CarolinaCodesElixir.Router do
  @moduledoc false
  use Plug.Router

  alias CarolinaCodesElixir.Catalog

  plug(:match)
  plug(:fetch_query_params)
  plug(:dispatch)

  get "/" do
    send_json(conn, 200, CarolinaCodesElixir.identity())
  end

  get "/health" do
    send_json(conn, 200, %{ok: true})
  end

  get "/v1/years" do
    send_json(conn, 200, %{"data" => Catalog.years()})
  end

  get "/v1/speakers" do
    year = parse_year(conn.query_params["year"])
    send_json(conn, 200, %{"data" => Catalog.list_speakers(year)})
  end

  get "/v1/speakers/:year/:slug" do
    case Integer.parse(year) do
      {y, ""} ->
        case Catalog.speaker_year(slug, y) do
          nil -> send_json(conn, 404, %{"error" => "not_found"})
          speaker -> send_json(conn, 200, %{"data" => speaker})
        end

      _ ->
        send_json(conn, 404, %{"error" => "not_found"})
    end
  end

  get "/v1/speakers/:slug" do
    case Catalog.speaker_detail(slug) do
      nil -> send_json(conn, 404, %{"error" => "not_found"})
      speaker -> send_json(conn, 200, %{"data" => speaker})
    end
  end

  get "/v1/sponsors" do
    year = parse_year(conn.query_params["year"])
    send_json(conn, 200, %{"data" => Catalog.list_sponsors(year)})
  end

  get "/v1/sponsors/:year/:slug" do
    case Integer.parse(year) do
      {y, ""} ->
        case Catalog.sponsor_year(slug, y) do
          nil -> send_json(conn, 404, %{"error" => "not_found"})
          sponsor -> send_json(conn, 200, %{"data" => sponsor})
        end

      _ ->
        send_json(conn, 404, %{"error" => "not_found"})
    end
  end

  get "/v1/sponsors/:slug" do
    case Catalog.sponsor_detail(slug) do
      nil -> send_json(conn, 404, %{"error" => "not_found"})
      sponsor -> send_json(conn, 200, %{"data" => sponsor})
    end
  end

  match _ do
    send_json(conn, 404, %{"error" => "not_found"})
  end

  defp parse_year(nil), do: nil
  defp parse_year(""), do: nil

  defp parse_year(value) do
    case Integer.parse(to_string(value)) do
      {year, ""} -> year
      _ -> nil
    end
  end

  defp send_json(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("x-polyglot-language", CarolinaCodesElixir.language())
    |> put_resp_header("x-polyglot-framework", CarolinaCodesElixir.framework())
    |> send_resp(status, Jason.encode!(body))
  end
end
