defmodule CarolinaCodesElixir.Register do
  @moduledoc false

  def run do
    url = System.get_env("CAROLINA_URL")
    token = System.get_env("POLYGLOT_REGISTER_TOKEN")

    if present?(url) and present?(token) do
      port = Application.get_env(:carolina_codes_elixir, :port) || 4015
      base = System.get_env("PUBLIC_BASE_URL") || "http://127.0.0.1:#{port}"

      body = %{
        "language" => CarolinaCodesElixir.language(),
        "language_version" => CarolinaCodesElixir.language_version(),
        "api_version" => CarolinaCodesElixir.api_version(),
        "framework" => CarolinaCodesElixir.framework(),
        "created_year" => CarolinaCodesElixir.created_year(),
        "schema_version" => CarolinaCodesElixir.schema_version(),
        "base_url" => base,
        "endpoints" => CarolinaCodesElixir.endpoints()
      }

      url = String.trim_trailing(url, "/") <> "/internal/api-endpoints/register"

      case Req.post(url,
             json: body,
             headers: [{"authorization", "Bearer #{token}"}],
             receive_timeout: 5_000,
             retry: false
           ) do
        {:ok, %{status: status}} ->
          IO.puts(:stderr, "registered with elixir: #{status}")

        {:error, err} ->
          IO.puts(:stderr, "register: #{Exception.message(err)}")
      end
    end
  rescue
    err ->
      IO.puts(:stderr, "register: #{Exception.message(err)}")
  end

  defp present?(nil), do: false
  defp present?(""), do: false
  defp present?(_), do: true
end
