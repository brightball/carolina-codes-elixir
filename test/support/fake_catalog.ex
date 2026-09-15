defmodule CarolinaCodesElixir.FakeCatalog do
  @moduledoc false

  def connect do
    Agent.start_link(fn -> :ok end)
  end

  def query(sql, params \\ []) do
    sql = IO.iodata_to_binary(sql)

    cond do
      String.contains?(sql, "FROM v1_speakers") -> speakers_query(sql, params)
      String.contains?(sql, "FROM v1_talks") -> talks_query(sql, params)
      String.contains?(sql, "FROM v1_year_sponsors") -> year_sponsors_query(sql, params)
      String.contains?(sql, "FROM v1_sponsors") -> sponsors_query(sql, params)
      String.contains?(sql, "FROM v1_sponsorships") -> sponsorships_query(sql, params)
      String.contains?(sql, "FROM v1_years") -> years()
      true -> []
    end
  end

  defp speakers_query(sql, params) do
    cond do
      String.contains?(sql, "v1_talks") -> speakers_for_year(params)
      String.contains?(sql, "WHERE slug =") -> speaker_by_slug(params)
      true -> speakers()
    end
  end

  defp talks_query(sql, params) do
    cond do
      String.contains?(sql, "ANY(") -> years_for_slugs(params)
      String.contains?(sql, "AND year") -> talks_for_slug_year(params)
      String.contains?(sql, "DISTINCT year") -> years_for_slug(params)
      String.contains?(sql, "speaker_slug") -> talks_for_slug(params)
      true -> talks_for_year(params)
    end
  end

  defp year_sponsors_query(sql, params) do
    if String.contains?(sql, "AND slug"),
      do: year_sponsor_by_slug(params),
      else: year_sponsors(params)
  end

  defp sponsors_query(sql, params) do
    if String.contains?(sql, "WHERE slug"), do: sponsor_by_slug(params), else: sponsors()
  end

  defp sponsorships_query(sql, params) do
    if String.contains?(sql, "DISTINCT year"), do: sponsor_years(params), else: []
  end

  defp speakers do
    [
      speaker("alice-smith", "Alice", "Smith"),
      speaker("bob-jones", "Bob", "Jones"),
      speaker("diana-pham", "Diana", "Pham")
    ]
  end

  defp speaker(slug, first, last) do
    %{
      "slug" => slug,
      "first_name" => first,
      "last_name" => last,
      "name" => first <> " " <> last,
      "tagline" => nil,
      "bio" => nil,
      "company" => nil,
      "location" => nil,
      "photo_path" => nil,
      "twitter_url" => nil,
      "linkedin_url" => nil,
      "website_url" => nil,
      "github_url" => nil,
      "featured" => false
    }
  end

  defp speakers_for_year(params) do
    year = year_param(params)

    slugs =
      talks()
      |> Enum.filter(&(&1["year"] == year))
      |> Enum.map(& &1["speaker_slug"])
      |> Enum.uniq()

    Enum.filter(speakers(), &(&1["slug"] in slugs))
  end

  defp speaker_by_slug(params) do
    slug = string_param(params, 0)
    Enum.filter(speakers(), &(&1["slug"] == slug))
  end

  defp talks do
    [
      talk("elixir-now", "Elixir Now", 2026, "diana-pham", ["Elixir"], ["BEAM"]),
      talk("elixir-then", "Elixir Then", 2025, "diana-pham", ["Elixir"], ["OTP"]),
      talk("alice-talk", "Alice Talk", 2026, "alice-smith", ["Elixir"], ["Phoenix"]),
      talk("bob-talk", "Bob Talk", 2026, "bob-jones", ["Erlang"], ["OTP"])
    ]
  end

  defp talk(slug, title, year, speaker_slug, languages, topics) do
    %{
      "slug" => slug,
      "title" => title,
      "description" => title,
      "format" => "talk",
      "youtube_id" => nil,
      "year" => year,
      "speaker_slug" => speaker_slug,
      "languages" => languages,
      "topics" => topics
    }
  end

  defp talks_for_year(params) do
    year = year_param(params)
    Enum.filter(talks(), &(&1["year"] == year))
  end

  defp talks_for_slug(params) do
    slug = string_param(params, 0)
    talks() |> Enum.filter(&(&1["speaker_slug"] == slug)) |> Enum.sort_by(& &1["year"], :desc)
  end

  defp talks_for_slug_year(params) do
    slug = string_param(params, 0)
    year = year_param(params, 1)

    Enum.filter(talks(), &(&1["speaker_slug"] == slug and &1["year"] == year))
  end

  defp years_for_slug(params) do
    slug = string_param(params, 0)

    talks()
    |> Enum.filter(&(&1["speaker_slug"] == slug))
    |> Enum.map(&%{"year" => &1["year"]})
    |> Enum.uniq()
    |> Enum.sort_by(& &1["year"], :desc)
  end

  defp years_for_slugs(params) do
    slugs = List.wrap(Enum.at(params, 0)) |> Enum.map(&to_string/1)

    talks()
    |> Enum.filter(&(&1["speaker_slug"] in slugs))
    |> Enum.map(&%{"speaker_slug" => &1["speaker_slug"], "year" => &1["year"]})
    |> Enum.uniq()
    |> Enum.sort_by(&{&1["speaker_slug"], -&1["year"]})
  end

  defp sponsors do
    [sponsor("flywheel", "Flywheel")]
  end

  defp sponsor(slug, name) do
    %{
      "slug" => slug,
      "name" => name,
      "website" => "https://example.com",
      "logo_path" => nil,
      "description" => name,
      "twitter_url" => nil,
      "linkedin_url" => nil,
      "youtube_url" => nil,
      "instagram_url" => nil,
      "facebook_url" => nil
    }
  end

  defp year_sponsors(params) do
    year = year_param(params)
    if year == 2026, do: [year_sponsor("flywheel", "Flywheel", year)], else: []
  end

  defp year_sponsor_by_slug(params) do
    year = year_param(params)
    slug = string_param(params, 1)

    year_sponsors([year])
    |> Enum.filter(&(&1["slug"] == slug))
  end

  defp year_sponsor(slug, name, year) do
    sponsor(slug, name)
    |> Map.merge(%{"tier" => "platinum", "featured" => true, "year" => year, "blurb" => name})
  end

  defp sponsor_by_slug(params) do
    slug = string_param(params, 0)
    Enum.filter(sponsors(), &(&1["slug"] == slug))
  end

  defp sponsor_years(params) do
    slug = string_param(params, 0)
    if slug == "flywheel", do: [%{"year" => 2026}], else: []
  end

  defp years do
    [
      %{
        "year" => 2026,
        "slug" => "2026",
        "name" => "Carolina Code Conference 2026",
        "status" => "upcoming"
      }
    ]
  end

  defp year_param(params, index \\ 0) do
    case Enum.at(params, index) do
      year when is_integer(year) -> year
      year when is_binary(year) -> String.to_integer(year)
      _ -> 2026
    end
  end

  defp string_param(params, index) do
    case Enum.at(params, index) do
      value when is_binary(value) -> value
      value -> to_string(value)
    end
  end
end
