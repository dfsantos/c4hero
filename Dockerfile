# syntax=docker/dockerfile:1

# ---- Build stage -----------------------------------------------------------
FROM node:22-alpine AS build
WORKDIR /app

# vite.config.ts reads the current commit hash via `git rev-parse` at build
# time, so the build stage needs both the git binary and the .git directory
# (kept in the build context — see .dockerignore).
RUN apk add --no-cache git

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# Optional build-time config (all unset by default — see .env.example).
# Vite inlines these into the bundle at build time, so they must be passed
# as --build-arg, not as container runtime env vars.
ARG VITE_LOG_ENDPOINT
ARG VITE_CLOUDFLARE_ANALYTICS_TOKEN
ARG VITE_SENTRY_DSN
ARG VITE_SENTRY_ENVIRONMENT
ARG VITE_WHATS_NEW

RUN npm run build

# ---- Runtime stage ----------------------------------------------------------
FROM nginxinc/nginx-unprivileged:1.27-alpine AS runtime

COPY --chown=nginx:nginx nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build --chown=nginx:nginx /app/dist /usr/share/nginx/html

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD wget -qO- http://127.0.0.1:8080/ > /dev/null || exit 1
