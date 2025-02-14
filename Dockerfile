# syntax = docker/dockerfile-upstream:master-labs

# build front-end
FROM --platform=${BUILDPLATFORM} node:lts-alpine AS frontend
RUN npm install pnpm -g

WORKDIR /app

COPY ./package.json /app
COPY ./pnpm-lock.yaml /app

RUN --mount=type=cache,target=/app/.pnpm-store pnpm install

ADD . /app

RUN --mount=type=cache,target=/app/.pnpm-store pnpm run build
RUN wget https://gobinaries.com/tj/node-prune --output-document - | /bin/sh
RUN node-prune

# build backend
FROM --platform=${BUILDPLATFORM} node:lts-alpine as backend

RUN npm install pnpm -g

WORKDIR /app

COPY /service/package.json /app
COPY /service/pnpm-lock.yaml /app

RUN --mount=type=cache,target=/app/.pnpm-store pnpm install

ADD --link /service /app

RUN --mount=type=cache,target=/app/.pnpm-store pnpm build
RUN wget https://gobinaries.com/tj/node-prune --output-document - | /bin/sh
RUN node-prune

FROM nginxinc/nginx-unprivileged:latest AS nginx
ADD ./docker-compose/nginx/nginx.conf /etc/nginx/conf.d/default.conf
COPY --link --from=frontend /app/dist /usr/share/nginx/html
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD curl -f http://localhost:8080/ || exit 1

FROM node:lts-alpine as node-lts-alpine
RUN npm install pnpm -g
RUN apk add upx curl
RUN upx /usr/local/bin/node
RUN apk del upx --purge
RUN rm -rf /usr/local/include/node/openssl/archs

# service
FROM node-lts-alpine AS service

WORKDIR /app
COPY /service/package.json /app
COPY /service/pnpm-lock.yaml /app

RUN --mount=type=cache,target=/app/.pnpm-store --mount=type=cache,target=/root/.cache --mount=type=tmpfs,target=/root/.local/share/pnpm pnpm install --production && rm -rf /root/.npm /root/.pnpm-store /usr/local/share/.cache /tmp/*

ADD /service /app

COPY --link --from=backend /app/build /app/build

EXPOSE 3002
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD wget 'http://localhost:3002/config' --post-data '{}' --header 'Content-Type: application/json' -O- || exit 1

CMD ["pnpm", "run", "prod"]
