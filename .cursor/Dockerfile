FROM hexpm/elixir:1.20.4-erlang-29.0.6-debian-trixie-20260824-slim
USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential git curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*
RUN mix local.hex --force && mix local.rebar --force
