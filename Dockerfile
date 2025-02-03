FROM elixir:1.18.0-alpine AS build

RUN apk update && apk add --no-cache build-base nodejs npm git

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only=prod

# COPY assets/package.json assets/package-lock.json ./assets/
# RUN cd assets && npm install

COPY . .

ENV MIX_ENV=prod

RUN mix deps.compile
RUN mix compile
RUN mix release
RUN mix phx.digest

# ----

FROM elixir:1.18.0-alpine AS app

RUN apk update && apk add --no-cache libstdc++ bash su-exec

WORKDIR /app

ENV MIX_ENV=prod \
    LANG=C.UTF-8 \
    PORT=4000 \
    DATABASE_PATH=/data/feedproxy.db \
    UID=1000 \
    GID=1000 \
    PHX_SERVER=true

COPY --from=build /app/_build/prod/rel/feedproxy /app
COPY --from=build /app/config /app/config
COPY --from=build /app/assets /app/assets

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 4000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["./bin/feedproxy", "start"]
