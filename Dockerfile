# Debian, not Alpine: musl DNS breaks Fly *.internal / flycast lookups
# (Phoenix's generated Dockerfile warns about the same Alpine DNS failures).
ARG ELIXIR_VERSION=1.20.4
ARG OTP_VERSION=29.0.6
ARG DEBIAN_VERSION=trixie-20260824-slim

ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="docker.io/debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS build
RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ENV MIX_ENV=prod
RUN mix local.hex --force && mix local.rebar --force
COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only prod && mix deps.compile
COPY lib lib
RUN mix compile && mix release

FROM ${RUNNER_IMAGE}
RUN apt-get update \
  && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 ca-certificates locales \
  && rm -rf /var/lib/apt/lists/* \
  && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
  && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
WORKDIR /app
RUN chown nobody /app
USER nobody
COPY --from=build --chown=nobody:nobody /app/_build/prod/rel/carolina_codes_elixir ./
ENV PORT=8080
ENV MIX_ENV=prod
ENV RELEASE_DISTRIBUTION=none
ENV ELIXIR_ERL_OPTIONS="+fnu"
EXPOSE 8080
CMD ["/app/bin/carolina_codes_elixir", "start"]
