############################################################################################
####  SERVER
############################################################################################

# Rust builder
FROM clux/muslrust:stable AS chef

USER root

# Install cargo-chef
RUN cargo install cargo-chef

WORKDIR /app

############################################################################################
####  PLANNER
############################################################################################

FROM chef AS planner

COPY ./pentaract .

RUN cargo chef prepare --recipe-path recipe.json

############################################################################################
####  BUILDER
############################################################################################

FROM chef AS builder

WORKDIR /app

# Copy recipe from planner
COPY --from=planner /app/recipe.json recipe.json

# Build dependencies (cached layer)
RUN cargo chef cook \
    --release \
    --target x86_64-unknown-linux-musl \
    --recipe-path recipe.json

# Copy full source
COPY ./pentaract .

# Build application
RUN cargo build \
    --release \
    --target x86_64-unknown-linux-musl

############################################################################################
####  UI
############################################################################################

FROM node:22-slim AS ui

WORKDIR /app

# Copy UI source
COPY ./ui .

# Install pnpm
RUN npm install -g pnpm

# Fix pnpm build-script issues
RUN pnpm config set ignore-scripts false
RUN pnpm config set unsafe-perm true

# Install dependencies
RUN pnpm install --no-frozen-lockfile

# Allow esbuild postinstall
RUN pnpm rebuild esbuild

# Environment variable
ENV VITE_API_BASE=/api

# Build frontend
RUN pnpm run build

############################################################################################
####  RUNTIME
############################################################################################

# Minimal runtime image
FROM scratch AS runtime

# Copy Rust binary
COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/pentaract /pentaract

# SSL certificates
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy frontend build
COPY --from=ui /app/dist /ui

# Start application
ENTRYPOINT ["/pentaract"]
```
