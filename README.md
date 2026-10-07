# carolina-codes-elixir

Standalone Elixir polyglot API for Carolina Code Conference. Queries PostgreSQL `v1_*` views over [Phoenix](https://www.phoenixframework.org/) (Bandit adapter). Distinct from the Phoenix CMS (`carolina-codes`).

## Versions

Pins in `mise.toml` and requirements in `mix.exs`:

- Elixir `1.20.4` (mise pin) and `~> 1.18` (`mix.exs` requirement)
- Erlang/OTP `29` (mise pin)
- Phoenix `~> 1.8.9`
- Bandit `~> 1.7` (HTTP server via `Bandit.PhoenixAdapter`)
- Req `~> 0.5` (outbound HTTP; registration only)
- Jason `~> 1.4` (JSON)
- Postgrex `~> 0.20` (SQL pool; this API does not use Ecto)
- Credo `~> 1.7` (strict lint, dev/test)
- Sobelow `~> 0.14` (security checks, dev/test)
- mix_audit `~> 2.1` (`deps.audit`, dev/test)
- Mint `~> 1.10` (HTTP client under Req)

## Run

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
