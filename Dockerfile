############################################################################################
#### SERVER
############################################################################################

FROM clux/muslrust:stable AS chef

USER root

# Install cargo-chef
RUN cargo install cargo-chef

WORKDIR /app

############################################################################################
#### PLANNER
############################################################################################

FROM chef AS planner

# Copy Rust backend source
COPY ./pentaract .

# Generate dependency recipe
RUN cargo chef prepare --recipe-path recipe.json

############################################################################################
#### BUILDER
############################################################################################

FROM chef AS builder

WORKDIR /app

# Copy dependency recipe
COPY --from=planner /app/recipe.json recipe.json

# Build dependency layer
RUN cargo chef cook --release --target x86_64-unknown-linux-musl --recipe-path recipe.json

# Copy full backend source
COPY ./pentaract .

# Build final binary
RUN cargo build --release --target x86_64-unknown-linux-musl

############################################################################################
#### UI
############################################################################################

FROM node:22-slim AS ui

WORKDIR /app

COPY ./ui .

# Install stable pnpm version
RUN npm install -g pnpm@8

# Allow scripts
RUN pnpm config set ignore-scripts false

# Install dependencies
RUN pnpm install --no-frozen-lockfile

# Rebuild esbuild binary
RUN pnpm rebuild esbuild

# Verify esbuild
RUN npx esbuild --version

# Frontend env
ENV VITE_API_BASE=/api

# Build frontend
RUN pnpm run build

############################################################################################
#### RUNTIME
############################################################################################

FROM alpine:latest AS runtime

WORKDIR /

# Install SSL certificates
RUN apk add --no-cache ca-certificates

# Copy Rust binary
COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/pentaract /pentaract

# Copy frontend build
COPY --from=ui /app/dist /ui

# Expose app port
EXPOSE 3000

# Start application
ENTRYPOINT ["/pentaract"]
