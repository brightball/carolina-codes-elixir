defmodule CarolinaCodesElixir.Catalog do
  @moduledoc false

  alias CarolinaCodesElixir.Db

  @speaker_cols "slug, first_name, last_name, name, tagline, bio, company, location, photo_path, twitter_url, linkedin_url, website_url, github_url, featured"
  @talk_cols "slug, title, description, format, youtube_id, year, speaker_slug, languages, topics"
  @year_sponsor_cols "slug, name, website, logo_path, description, blurb, tier, featured, year, twitter_url, linkedin_url, youtube_url, instagram_url, facebook_url"
  @sponsor_cols "slug, name, website, logo_path, description, twitter_url, linkedin_url, youtube_url, instagram_url, facebook_url"

  def years do
    Db.query("SELECT year, slug, name, status FROM v1_years ORDER BY year DESC")
    |> Enum.map(&clean/1)
  end

  def list_speakers(nil) do
    Db.query("SELECT #{@speaker_cols} FROM v1_speakers ORDER BY last_name, first_name")
    |> Enum.map(&clean/1)
  end

  def list_speakers(year) do
    speakers =
      Db.query(
        "SELECT #{@speaker_cols} FROM v1_speakers " <>
          "WHERE slug IN (SELECT speaker_slug FROM v1_talks WHERE year = $1) " <>
          "ORDER BY last_name, first_name",
        [year]
      )
      |> Enum.map(&clean/1)

    attach_year_tags(speakers, year)
  end

  def speaker_detail(slug) do
    case load_speaker(slug) do
      nil ->
        nil

      speaker ->
        talks = talks_for(slug, nil)

        speaker
        |> Map.put("talks", talks)
        |> Map.put("years", Enum.map(talks, & &1["year"]) |> Enum.uniq() |> Enum.sort(:desc))
    end
  end

  def speaker_year(slug, year) do
    speaker = load_speaker(slug)
    talks = talks_for(slug, year)

    cond do
      is_nil(speaker) or talks == [] ->
        nil

      true ->
        years = talk_years(slug)

        speaker
        |> Map.merge(%{
          "year" => year,
          "years" => years,
          "other_years" => Enum.reject(years, &(&1 == year)),
          "talks" => talks,
          "languages" => uniq_tags(talks, "languages"),
          "topics" => uniq_tags(talks, "topics")
        })
    end
  end

  def list_sponsors(nil) do
    Db.query("SELECT #{@sponsor_cols} FROM v1_sponsors ORDER BY name")
    |> Enum.map(&clean/1)
  end

  def list_sponsors(year) do
    Db.query(
      "SELECT #{@year_sponsor_cols} FROM v1_year_sponsors WHERE year = $1 ORDER BY name",
      [year]
    )
    |> Enum.map(&clean/1)
  end

  def sponsor_detail(slug) do
    case Db.query_one("SELECT #{@sponsor_cols} FROM v1_sponsors WHERE slug = $1", [slug]) do
      nil ->
        nil

      row ->
        sponsorships =
          Db.query("SELECT * FROM v1_sponsorships WHERE sponsor_slug = $1", [slug])
          |> Enum.map(&clean/1)

        row |> clean() |> Map.put("sponsorships", sponsorships)
    end
  end

  def sponsor_year(slug, year) do
    case Db.query_one(
           "SELECT #{@year_sponsor_cols} FROM v1_year_sponsors WHERE year = $1 AND slug = $2",
           [year, slug]
         ) do
      nil ->
        nil

      row ->
        years = sponsor_years(slug)

        row
        |> clean()
        |> Map.merge(%{
          "years" => years,
          "other_years" => Enum.reject(years, &(&1 == year))
        })
    end
  end

  defp load_speaker(slug) do
    Db.query_one("SELECT #{@speaker_cols} FROM v1_speakers WHERE slug = $1", [slug])
    |> clean()
  end

  defp attach_year_tags([], _year), do: []

  defp attach_year_tags(speakers, year) do
    slugs = Enum.map(speakers, & &1["slug"])
    talks_by = load_talks_for_year(year)
    years_by = load_years_for_slugs(slugs)

    Enum.map(speakers, fn speaker ->
      slug = speaker["slug"]
      talks = Map.get(talks_by, slug, [])
      years = Map.get(years_by, slug, [])

      Map.merge(speaker, %{
        "year" => year,
        "talks" => talks,
        "languages" => uniq_tags(talks, "languages"),
        "topics" => uniq_tags(talks, "topics"),
        "years" => years
      })
    end)
  end

  defp load_talks_for_year(year) do
    Db.query(
      "SELECT #{@talk_cols} FROM v1_talks WHERE year = $1 ORDER BY speaker_slug, year DESC",
      [year]
    )
    |> Enum.map(&clean/1)
    |> Enum.group_by(& &1["speaker_slug"])
  end

  defp load_years_for_slugs([]), do: %{}

  defp load_years_for_slugs(slugs) do
    Db.query(
      "SELECT DISTINCT speaker_slug, year FROM v1_talks WHERE speaker_slug = ANY($1) ORDER BY speaker_slug, year DESC",
      [slugs]
    )
    |> Enum.reduce(%{}, fn row, acc ->
      slug = row["speaker_slug"]
      year = as_int(row["year"])
      Map.update(acc, slug, [year], &(&1 ++ [year]))
    end)
  end

  defp talks_for(slug, nil) do
    Db.query(
      "SELECT #{@talk_cols} FROM v1_talks WHERE speaker_slug = $1 ORDER BY year DESC",
      [slug]
    )
    |> Enum.map(&clean/1)
  end

  defp talks_for(slug, year) do
    Db.query(
      "SELECT #{@talk_cols} FROM v1_talks WHERE speaker_slug = $1 AND year = $2 ORDER BY year DESC",
      [slug, year]
    )
    |> Enum.map(&clean/1)
  end

  defp talk_years(slug) do
    Db.query(
      "SELECT DISTINCT year FROM v1_talks WHERE speaker_slug = $1 ORDER BY year DESC",
      [slug]
    )
    |> Enum.map(&as_int(&1["year"]))
  end

  defp sponsor_years(slug) do
    Db.query(
      "SELECT DISTINCT year FROM v1_sponsorships WHERE sponsor_slug = $1 ORDER BY year DESC",
      [slug]
    )
    |> Enum.map(&as_int(&1["year"]))
  end

  defp uniq_tags(talks, key) do
    talks
    |> Enum.flat_map(&as_string_array(Map.get(&1, key)))
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp clean(nil), do: nil

  defp clean(row) when is_map(row) do
    Map.new(row, fn {k, v} ->
      key = to_string(k)

      value =
        cond do
          key in ["languages", "topics"] -> as_string_array(v)
          key == "featured" -> v in [true, 1, "t", "true"]
          key == "year" and not is_nil(v) -> as_int(v)
          match?(%Date{}, v) -> Date.to_iso8601(v)
          match?(%NaiveDateTime{}, v) -> NaiveDateTime.to_iso8601(v)
          true -> v
        end

      {key, value}
    end)
  end

  defp as_string_array(nil), do: []

  defp as_string_array(list) when is_list(list),
    do: Enum.map(list, &to_string/1) |> Enum.reject(&(&1 == ""))

  defp as_string_array(value) when is_binary(value) do
    stripped = String.trim(value)
    if stripped in ["", "{}"], do: [], else: parse_pg_array(stripped)
  end

  defp as_string_array(_), do: []

  defp parse_pg_array(stripped) do
    inner =
      if String.starts_with?(stripped, "{") and String.ends_with?(stripped, "}") do
        String.slice(stripped, 1..-2//1)
      else
        stripped
      end

    inner
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.trim(&1, "\""))
    |> Enum.reject(&(&1 == ""))
  end

  defp as_int(v) when is_integer(v), do: v
  defp as_int(v) when is_binary(v), do: String.to_integer(v)
  defp as_int(v) when is_float(v), do: trunc(v)
  defp as_int(v), do: v
end
