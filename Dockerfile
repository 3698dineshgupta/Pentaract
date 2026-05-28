############################################################################################
#### RUST BASE (CHEF)
############################################################################################
FROM clux/muslrust:stable AS chef
USER root

RUN cargo install cargo-chef

WORKDIR /app/pentaract

############################################################################################
#### PLANNER
############################################################################################
FROM chef AS planner

# Copy only Rust backend
COPY ./pentaract .

RUN cargo chef prepare --recipe-path recipe.json

############################################################################################
#### BUILDER
############################################################################################
FROM chef AS builder

WORKDIR /app/pentaract

COPY --from=planner /app/pentaract/recipe.json recipe.json

RUN cargo chef cook --release --target x86_64-unknown-linux-musl --recipe-path recipe.json

# now copy full backend source
COPY ./pentaract .

RUN cargo build --release --target x86_64-unknown-linux-musl

############################################################################################
#### UI BUILD
############################################################################################
FROM node:22-slim AS ui

WORKDIR /app

COPY ./ui .

RUN npm install -g pnpm@9
RUN pnpm install --no-frozen-lockfile
RUN pnpm rebuild esbuild

ENV VITE_API_BASE=/api

RUN pnpm run build

############################################################################################
#### RUNTIME
############################################################################################
FROM alpine:latest AS runtime

WORKDIR /

RUN apk add --no-cache ca-certificates

# Rust binary
COPY --from=builder /app/pentaract/target/x86_64-unknown-linux-musl/release/pentaract /pentaract

# UI build output
COPY --from=ui /app/dist /ui

EXPOSE 3000

ENTRYPOINT ["/pentaract"]
