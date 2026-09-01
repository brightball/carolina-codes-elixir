FROM hexpm/elixir:1.20.4-erlang-29.0.6-alpine-3.22.5 AS build
RUN apk add --no-cache build-base git
WORKDIR /app
ENV MIX_ENV=prod
RUN mix local.hex --force && mix local.rebar --force
COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only prod && mix deps.compile
COPY lib lib
RUN mix compile && mix release

FROM alpine:3.22
RUN apk add --no-cache libstdc++ ncurses-libs openssl
WORKDIR /app
RUN chown nobody /app
USER nobody
COPY --from=build --chown=nobody:nobody /app/_build/prod/rel/carolina_codes_elixir ./
ENV PORT=8080
ENV MIX_ENV=prod
EXPOSE 8080
CMD ["/app/bin/carolina_codes_elixir", "start"]
