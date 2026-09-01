# carolina-codes-elixir

Standalone Elixir polyglot API for Carolina Code Conference. Queries PostgreSQL `v1_*` views over [Bandit](https://github.com/mtrudel/bandit) + Plug. Distinct from the Phoenix CMS (`carolina-codes`).

```
mix deps.get
DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/carolina_dev \
CAROLINA_URL=http://127.0.0.1:4000 \
POLYGLOT_REGISTER_TOKEN=dev \
PUBLIC_BASE_URL=http://127.0.0.1:4015 \
PORT=4015 \
mix run --no-halt
```

`GET /` reports `language: "Elixir"` and `framework: "Bandit"`.
