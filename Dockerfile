# syntax = docker/dockerfile-upstream:master-labs

# build front-end
FROM --platform=${BUILDPLATFORM} node:lts-alpine AS builder

COPY ./ /app
WORKDIR /app

RUN npm install pnpm -g
RUN --mount=type=cache,target=/app/.pnpm-store pnpm install
ENV NODE_ENV=production
RUN --mount=type=cache,target=/app/.pnpm-store pnpm run build
RUN wget https://gobinaries.com/tj/node-prune --output-document - | /bin/sh
RUN node-prune

# build nginx
FROM nginxinc/nginx-unprivileged:latest as nginx

ADD ./docker-compose/nginx/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder --link /app/dist/ /usr/share/nginx/html/
EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]


# service-builder
FROM --platform=${BUILDPLATFORM} node:lts-alpine as service-builder

ADD ./service /app
ENV NODE_ENV=production
WORKDIR /app
RUN --mount=type=cache,target=/app/.pnpm-store npm install pnpm -g
RUN --mount=type=cache,target=/app/.pnpm-store pnpm install
RUN wget https://gobinaries.com/tj/node-prune --output-document - | /bin/sh
RUN node-prune

FROM node:lts-alpine as service
COPY --from=service-builder --link /app /app
WORKDIR /app
CMD ["npm", "run", "start"]
