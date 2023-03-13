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
FROM node:lts-alpine as backend

RUN npm install pnpm -g

WORKDIR /app

COPY /service/package.json /app
COPY /service/pnpm-lock.yaml /app

RUN --mount=type=cache,target=/app/.pnpm-store pnpm install

ADD /service /app

RUN --mount=type=cache,target=/app/.pnpm-store pnpm build
RUN wget https://gobinaries.com/tj/node-prune --output-document - | /bin/sh
RUN node-prune

# service
FROM node:lts-alpine
RUN npm install pnpm -g
WORKDIR /app
COPY /service/package.json /app
COPY /service/pnpm-lock.yaml /app

RUN --mount=type=cache,target=/app/.pnpm-store pnpm install --production && rm -rf /root/.npm /root/.pnpm-store /usr/local/share/.cache /tmp/*

ADD /service /app

COPY --link --from=frontend /app/dist /app/public
COPY --link --from=backend /app/build /app/build

EXPOSE 3002

CMD ["pnpm", "run", "prod"]
