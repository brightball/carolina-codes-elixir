# Memory

Current facts for this API. Update a fact in place when it changes. Why a choice was made is in `DECISIONS.md`. Do not store secrets, production credentials, non-public hostnames, or personal contact data here.

## Stack

- Elixir requirement `~> 1.18` (`mix.exs`). Mise pins Elixir `1.20.4` and Erlang/OTP `29`.
- Phoenix `~> 1.8.9` with `Bandit.PhoenixAdapter` (`bandit ~> 1.7`). Not a raw `Plug.Router`.
- No LiveView, Ecto, Ash, or asset pipeline.
- JSON is Jason. SQL is a Postgrex pool in `CarolinaCodesElixir.Db`.
- Outbound HTTP is Req only (`~> 0.5`). No `:httpc`, HTTPoison, or Tesla.

## Contract

- Routes and payloads come from the CMS files `priv/api/openapi.yaml` and `priv/api/AGENTS.md`. This repo does not ship an OpenAPI file.
- Read-only queries of the `v1_*` views: `v1_speakers`, `v1_sponsors`, `v1_years`, `v1_talks`, `v1_sponsorships`, `v1_year_sponsors`, `v1_year_speakers`.
- Do not query Ash tables or base tables (`speakers`, `organizations`, `talks`). Do not speak Ash JSON:API.
- Identity is `language` `"Elixir"` and `framework` `"Phoenix"`.
- Default listen port is `4015`. The listener is IPv6 `::` with `ipv6_v6only: false`.

## Runtime

- `GET /health` returns `{ "ok": true }` and does not hit the database.
- Registration runs once on boot via Req. If `CAROLINA_URL` or the token is unset, skip it and keep serving. If the CMS is down, log and keep serving. No heartbeat.
- Register URLs that contain `.internal:` use Req `inet6: true`. Other hosts do not.
- `GET /` and the catalog routes are the list in `CarolinaCodesElixir.endpoints/0`.

## Tests and quality

- Handler tests use `CarolinaCodesElixir.FakeCatalog` (`config/test.exs`). They do not need Postgres.
- `mix precommit` and `mise run check` run compile --warnings-as-errors, format, credo --strict, sobelow, deps.audit, gitleaks detect, and tests.
- `mise run secrets` runs gitleaks.
- Quality packages in `mix.exs`: Credo `~> 1.7`, Sobelow `~> 0.14`, mix_audit `~> 2.1` (dev and test only).
