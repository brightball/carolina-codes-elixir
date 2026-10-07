# Decisions

Durable choices already implemented in this API. `MEMORY.md` is what is true now. This file is why.

Each entry has a status, brief context, the choice, and the consequence. Status is `accepted` or `superseded`. Accepted entries bind. A superseded entry stays in this file, names the entry that replaced it, and does not govern current work. The status line is what makes them distinguishable.

Git history is the changelog. Do not add amendment logs inside an entry. When a durable choice changes, append a new accepted entry and set the old entry's status to `superseded`. Do not delete the old entry.

Do not put secrets, production credentials, non-public hostnames, or personal contact data in this file.

## D1. Raw Plug.Router on Bandit

- **Status:** superseded by D2
- **Context:** The listener was a Bandit child with a `Plug.Router` plug. That shape could not host Phoenix controllers, the endpoint pipeline, or the polyglot response headers.
- **Choice:** Serve the polyglot routes from a `Plug.Router` module supervised as `{Bandit, plug: ...}`.
- **Consequence:** Superseded. Do not put a raw Bandit child or `Plug.Router` back in `CarolinaCodesElixir.Application`. D2 governs.

## D2. Phoenix with the Bandit adapter

- **Status:** accepted
- **Supersedes:** D1
- **Context:** The API needs Phoenix routing and JSON controllers. It does not render HTML, does not own a database schema, and does not need LiveView or an asset build.
- **Choice:** `CarolinaCodesElixirWeb.Endpoint` uses `Bandit.PhoenixAdapter`. The application supervises that endpoint. Identity `framework` is `"Phoenix"`. Do not add LiveView, Ecto, Ash, or an asset pipeline.
- **Consequence:** HTTP goes through the Phoenix endpoint and router. Bandit is the adapter, not the application framework. A raw `Plug.Router` is out of bounds.

## D3. SQL contract is the v1 views

- **Status:** accepted
- **Context:** Catalog rows are owned by the CMS. Ash tables and base tables are not the public contract, and this process must not write.
- **Choice:** Read only `v1_speakers`, `v1_sponsors`, `v1_years`, `v1_talks`, `v1_sponsorships`, `v1_year_sponsors`, and `v1_year_speakers` through Postgrex in `CarolinaCodesElixir.Db`. No Ecto.
- **Consequence:** Catalog changes follow the CMS views. Queries against Ash tables or base tables are wrong even if they happen to return rows.

## D4. HTTP contract lives in the CMS

- **Status:** accepted
- **Context:** Every polyglot sibling implements one contract. A second OpenAPI file in this repo would drift.
- **Choice:** Routes and payloads follow CMS `priv/api/openapi.yaml` and `priv/api/AGENTS.md`. This repo does not vendor that document. Responses are ordinary JSON, not Ash JSON:API (`application/vnd.api+json`).
- **Consequence:** Contract edits happen in the CMS. Do not add an in-repo OpenAPI file as the source of truth.

## D5. Outbound HTTP is Req only

- **Status:** accepted
- **Context:** The only outbound call is registration. Several HTTP clients would leave two stacks to patch.
- **Choice:** Call the CMS with Req (`~> 0.5`). Do not add `:httpc`, HTTPoison, or Tesla.
- **Consequence:** Registration options, including the `.internal:` inet6 switch, stay in `CarolinaCodesElixir.Register`.

## D6. Register once and keep serving

- **Status:** accepted
- **Context:** The CMS keeps at most one language API warm and probes it. This process must boot when the CMS is down.
- **Choice:** `CarolinaCodesElixir.Application` starts `CarolinaCodesElixir.Register.run/0` once. There is no heartbeat. A missing `CAROLINA_URL` or token skips the call. A failed POST is logged. Either way the listener keeps serving. Registration does not open Postgres or run catalog SQL.
- **Consequence:** Do not add a retry loop, a heartbeat, or a database call to registration.

## D7. Health does not touch Postgres

- **Status:** accepted
- **Context:** Liveness has to succeed before the pool is useful, including while Postgres is down.
- **Choice:** `GET /health` returns `{ "ok": true }` and does not query or connect. Counters are created before the listener accepts. The pool is a later child.
- **Consequence:** Do not add a `SELECT` or a pool checkout to the health action.

## D8. Handler tests use FakeCatalog

- **Status:** accepted
- **Context:** Catalog behavior is SQL against CMS views. CI and local `mix test` must run without that database.
- **Choice:** `config/test.exs` points `query_fn` and `connect_fn` at `CarolinaCodesElixir.FakeCatalog`. Handler tests do not need Postgres.
- **Consequence:** New handler tests use the fake. Do not require a live `DATABASE_URL` for `mix test`.

## D9. Default listen port is 4015

- **Status:** accepted
- **Context:** Each polyglot sibling needs its own local port so it can run next to the CMS on port 4000.
- **Choice:** `PORT` defaults to `4015` in `config/runtime.exs`. `PUBLIC_BASE_URL` defaults to `http://127.0.0.1:{PORT}` when unset.
- **Consequence:** Docs, local run commands, and the register `base_url` fallback stay on 4015 unless `PORT` is set.

## D10. Quality command is mix precommit

- **Status:** accepted
- **Context:** Agents and CI need one command that matches the gates already wired in `mix.exs`.
- **Choice:** `mix precommit` and `mise run check` run compile --warnings-as-errors, unused-dep check, `deps.audit`, format, credo --strict, sobelow, gitleaks detect, and tests. `precommit` prefers the `:test` env. Credo `~> 1.7`, Sobelow `~> 0.14`, and mix_audit `~> 2.1` are dev/test deps. `mise run secrets` is gitleaks alone.
- **Consequence:** A change is not done until `mix precommit` passes. Do not drop one of those steps from the alias without a new decision.

## D11. Dual-stack listen

- **Status:** accepted
- **Context:** The process must accept local IPv4 clients and IPv6 peers on one socket.
- **Choice:** Bind `CarolinaCodesElixir.listen_ip/0` (`::`) with `ipv6_v6only: false`. Do not bind the IPv4 any-address.
- **Consequence:** Runtime config keeps that listen shape. An IPv4-only bind breaks the dual-stack requirement.

## D12. inet6 only for .internal register URLs

- **Status:** accepted
- **Context:** Some register targets have no A record. Req and Mint then fail the lookup. Forcing inet6 on every URL breaks plain IPv4 localhost.
- **Choice:** `CarolinaCodesElixir.Register.req_opts/1` sets `inet6: true` only when the URL contains `.internal:`. Retry stays off. Other hosts use the default address family.
- **Consequence:** Do not force inet6 globally, and do not remove the `.internal:` branch.
