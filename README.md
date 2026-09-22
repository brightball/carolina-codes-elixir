# carolina-codes-elixir

Standalone Elixir polyglot API for Carolina Code Conference. Queries PostgreSQL `v1_*` views over [Phoenix](https://www.phoenixframework.org/) (Bandit adapter). Distinct from the Phoenix CMS (`carolina-codes`).

```
mix deps.get
DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/carolina_dev \
CAROLINA_URL=http://127.0.0.1:4000 \
POLYGLOT_REGISTER_TOKEN=dev \
PUBLIC_BASE_URL=http://127.0.0.1:4015 \
PORT=4015 \
mix phx.server
```

`GET /` reports `language: "Elixir"` and `framework: "Phoenix"`.

Quality gates (same spirit as the CMS, without Ash/migration steps). `mix precommit` and `mise run check` both run compile-warnings-as-errors, format, credo --strict, sobelow, deps.audit, gitleaks detect, and tests:

```
mix precommit
mise run check
mise run secrets   # gitleaks detect --source .
```

Gitea Actions (`.gitea/workflows/precommit.yml`) prepares the Mix workspace once (`prep`: token-clone `GITHUB_SHA`, toolchain, `mix deps.get`, Mix compile), then each Mix check from the `precommit` alias restores that artifact and runs only its Mix command. Mix checks wait on `prep` (not on each other) and do not re-clone, `mix deps.get`, or install `build-essential`. `gitleaks detect --source . --verbose` is a separate job. This is not a single `mix precommit` CI step.
