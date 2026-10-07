# carolina-codes-elixir

Finished read-only v1 polyglot API. Phoenix serves it through the Bandit adapter (`Bandit.PhoenixAdapter`). This is not a raw `Plug.Router` app. It does not use LiveView, Ecto, Ash, or an asset pipeline.

The source of truth for routes and payloads is the CMS files `priv/api/openapi.yaml` and `priv/api/AGENTS.md`. This repository does not vendor that document. If the public contract changes, change it in the CMS. Do not implement Ash JSON:API (`application/vnd.api+json`). Responses are ordinary JSON over the v1 REST + SQL-view contract.

You do not need a checkout of the Elixir CMS to run this API. Registration is best-effort: if `CAROLINA_URL` is unset or the CMS is down, skip or no-op the register call and still serve HTTP.

`MEMORY.md` is the current facts. `DECISIONS.md` is why. Accepted decisions bind. See [Agent memory](#agent-memory).

## Purpose

The Phoenix CMS keeps at most one language API warm and reads speakers and sponsors from it. This process must:

1. Query PostgreSQL `v1_*` views, never Ash resource tables and never base tables.
2. Expose the routes below (the same list as the CMS contract).
3. Register once on boot with the CMS (no heartbeat). If the CMS is not running, log and continue.

## Environment

| Variable | Example | Role |
| --- | --- | --- |
| `DATABASE_URL` | `postgres://postgres:postgres@127.0.0.1:5432/carolina_dev` | CMS SQL views |
| `CAROLINA_URL` | `http://127.0.0.1:4000` | CMS (optional; register no-ops if down) |
| `POLYGLOT_REGISTER_TOKEN` | `dev` | Bearer token for register |
| `PUBLIC_BASE_URL` | `http://127.0.0.1:4015` | URL the CMS will call |
| `PORT` | `4015` | Listen port (default 4015) |

The views live in the CMS database. This repo does not ship Compose, a catalog schema, or seed data. Handler tests do not need Postgres. For live HTTP against the views, start the CMS database and export the variables above.

Default listen port is 4015. The listener binds IPv6 `::` with `ipv6_v6only: false` so local IPv4 and IPv6 both work.

## SQL views (query these)

`v1_speakers`, `v1_sponsors`, `v1_years`, `v1_talks`, `v1_sponsorships`, `v1_year_sponsors`, `v1_year_speakers`.

Year-scoped speaker rows come from `v1_talks` (languages and topics). Year-scoped sponsor rows come from `v1_year_sponsors` and include `tier` (and `blurb`).

Do not `SELECT` from `speakers`, `organizations`, `talks`, or other base tables. Do not query Ash tables. The views are the API. Catalog SQL goes through `CarolinaCodesElixir.Catalog` and the Postgrex pool in `CarolinaCodesElixir.Db`. Do not add Ecto.

## Required HTTP routes

Wrap list payloads as `{ "data": [ ... ] }` unless the action returns one record as `{ "data": { ... } }`. Unknown slugs return 404 `{ "error": "not_found" }`.

- `GET /health` — liveness (`{ "ok": true }`). This check does not hit the database. Do not add a query or a pool checkout to it.
- `GET /` — identity (`language` `"Elixir"`, `framework` `"Phoenix"`, `api_version`, `endpoints`)
- `GET /v1/years`
- `GET /v1/speakers` and `GET /v1/speakers?year=2025`
- `GET /v1/speakers/{slug}` and `GET /v1/speakers/{year}/{slug}`
- `GET /v1/sponsors` and `GET /v1/sponsors?year=2025`
- `GET /v1/sponsors/{slug}` and `GET /v1/sponsors/{year}/{slug}`

`?year=` listing rows include `languages` / `topics` (speakers) and `tier` (sponsors).

`photo_path` / `logo_path` values are web paths. Return the path. The CMS hosts the files. This repo does not serve those bytes.

## Register on boot (once)

`POST {CAROLINA_URL}/internal/api-endpoints/register`

```
Authorization: Bearer {POLYGLOT_REGISTER_TOKEN}
Content-Type: application/json
```

`CarolinaCodesElixir.Register.run/0` sends `language`, `language_version`, `api_version`, `framework`, `created_year`, `schema_version` (1), `base_url` (`PUBLIC_BASE_URL`, or `http://127.0.0.1:{PORT}`), and `endpoints` from `CarolinaCodesElixir.endpoints/0`. Outbound HTTP is Req only. Do not add `:httpc`, HTTPoison, or Tesla.

The application starts that call once. Do not heartbeat. The CMS keep-alives the currently warm API.

If `CAROLINA_URL` or `POLYGLOT_REGISTER_TOKEN` is empty, skip the call and keep serving. If the POST fails (connection refused, 4xx/5xx), log and keep serving. Registration must not open Postgres or run catalog SQL.

Req turns on `inet6` only when the register URL contains `.internal:`. Leave that in place. Other hosts stay on the default address family.

## Layout

| Path | Role |
| --- | --- |
| `lib/carolina_codes_elixir.ex` | Identity, version, route list |
| `lib/carolina_codes_elixir/catalog.ex` | Read-only queries of the `v1_*` views |
| `lib/carolina_codes_elixir/db.ex` | Postgrex pool (not Ecto) |
| `lib/carolina_codes_elixir/register.ex` | One-shot Req registration |
| `lib/carolina_codes_elixir/application.ex` | Supervisor: PubSub, Phoenix endpoint, pool; then register |
| `lib/carolina_codes_elixir_web/` | Endpoint, router, JSON controllers |
| `config/config.exs` | `adapter: Bandit.PhoenixAdapter` |
| `config/runtime.exs` | `PORT` default 4015, dual-stack listen |
| `config/test.exs` | `FakeCatalog` query and connect hooks |
| `test/support/fake_catalog.ex` | In-memory catalog. Handler tests do not need Postgres |
| `mix.exs`, `mise.toml` | Deps, Elixir/OTP pins, `mix precommit` |
| `MEMORY.md` | Current facts. Update in place |
| `DECISIONS.md` | Durable choices. Append or supersede |
| `Dockerfile`, `fly.toml` | Release image and Fly config for this API |

There is no in-repo `openapi.yaml`. Do not add one. Contract: CMS `priv/api/openapi.yaml` + `priv/api/AGENTS.md`.

## Quality

`mix precommit` and `mise run check` both run compile --warnings-as-errors, `deps.unlock --check-unused`, `deps.audit`, format, credo --strict, sobelow, gitleaks detect, and tests. `mise run secrets` runs gitleaks. `mix precommit` prefers the `:test` env.

This repo is the workspace root. The Phoenix CMS is a different remote (`github.com/brightball/carolina-codes`). Do not assume a sibling checkout exists. Do not fold this tree into the CMS git remote.

## Checklist

- All contract paths return 200 with the JSON shape above (404 on an unknown slug)
- `?year=` listing rows include `languages` / `topics` (speakers) and `tier` (sponsors)
- Register runs once at process start; log and keep serving if the CMS is down; no heartbeat
- `GET /health` is cheap and does not hit the database
- No writes; no Ash table names; no Ash JSON:API
- Outbound HTTP stays on Req
- Handler tests keep using `CarolinaCodesElixir.FakeCatalog` and do not require Postgres

## Agent memory

Elixir agents enter a Mix repo through the root `AGENTS.md`. Keep this file as the contract and the map. Put facts and rationale in the two files below so this one does not become a changelog.

- `MEMORY.md` holds current facts only, in the present tense. Update memory in place: rewrite the line that changed. Do not append a second copy of an old fact. Git history is the changelog.
- `DECISIONS.md` holds one durable choice per entry. Each entry has a status, brief context, the choice, and the consequence. Status is `accepted` or `superseded`.
- Accepted entries bind. When a task conflicts with one, change the decision in the same change as the code. Append a new accepted entry and mark the old one superseded. Do not silently contradict it.
- A superseded entry stays in the file, names the entry that replaced it, and does not govern current work. Accepted and superseded entries stay distinguishable by that status line.
- Do not delete accepted history and do not add amendment logs inside an entry. Git history is the changelog.
- Keep every decision in `DECISIONS.md`. Do not split a `docs/decisions/` tree.
- Do not install Phoenix `usage_rules`. Those notes describe LiveView, Ecto, and the asset pipeline, which this API does not use.
- Credo, Sobelow, and `mix_audit` already enforce lint, security, and advisory checks. Do not copy those rule lists into `MEMORY.md`.
- Do not put secrets, production credentials, non-public hostnames, or personal contact data in `AGENTS.md`, `README.md`, `MEMORY.md`, or `DECISIONS.md`. Localhost examples (`postgres:postgres`, `POLYGLOT_REGISTER_TOKEN=dev`, `127.0.0.1`) are fine.
