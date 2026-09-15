defmodule CarolinaCodesElixirWeb.CatalogController do
  use CarolinaCodesElixirWeb, :controller

  alias CarolinaCodesElixir.Catalog

  def years(conn, _params) do
    json(conn, %{"data" => Catalog.years()})
  end

  def speakers(conn, params) do
    json(conn, %{"data" => Catalog.list_speakers(parse_year(params["year"]))})
  end

  def speaker(conn, %{"slug" => slug}) do
    case Catalog.speaker_detail(slug) do
      nil -> send_not_found(conn)
      speaker -> json(conn, %{"data" => speaker})
    end
  end

  def speaker_year(conn, %{"year" => year, "slug" => slug}) do
    case Integer.parse(year) do
      {y, ""} ->
        case Catalog.speaker_year(slug, y) do
          nil -> send_not_found(conn)
          speaker -> json(conn, %{"data" => speaker})
        end

      _ ->
        send_not_found(conn)
    end
  end

  def sponsors(conn, params) do
    json(conn, %{"data" => Catalog.list_sponsors(parse_year(params["year"]))})
  end

  def sponsor(conn, %{"slug" => slug}) do
    case Catalog.sponsor_detail(slug) do
      nil -> send_not_found(conn)
      sponsor -> json(conn, %{"data" => sponsor})
    end
  end

  def sponsor_year(conn, %{"year" => year, "slug" => slug}) do
    case Integer.parse(year) do
      {y, ""} ->
        case Catalog.sponsor_year(slug, y) do
          nil -> send_not_found(conn)
          sponsor -> json(conn, %{"data" => sponsor})
        end

      _ ->
        send_not_found(conn)
    end
  end

  defp parse_year(nil), do: nil
  defp parse_year(""), do: nil

  defp parse_year(value) do
    case Integer.parse(to_string(value)) do
      {year, ""} -> year
      _ -> nil
    end
  end

  defp send_not_found(conn) do
    conn
    |> put_status(:not_found)
    |> json(%{"error" => "not_found"})
  end
end
