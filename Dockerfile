############################################################################################
# 1. CHEF BASE
############################################################################################
FROM clux/muslrust:stable AS chef

USER root
RUN cargo install cargo-chef --locked
WORKDIR /app

############################################################################################
# 2. PLANNER
############################################################################################
FROM chef AS planner

COPY Cargo.toml Cargo.lock ./
COPY pentaract ./pentaract

RUN cargo chef prepare --recipe-path recipe.json

############################################################################################
# 3. BUILDER (RUST BACKEND)
############################################################################################
FROM chef AS builder

WORKDIR /app

COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --release --target x86_64-unknown-linux-musl --recipe-path recipe.json

COPY Cargo.toml Cargo.lock ./
COPY pentaract ./pentaract

RUN cargo build --release --target x86_64-unknown-linux-musl

############################################################################################
# 4. UI BUILD
############################################################################################
FROM node:22-slim AS ui

WORKDIR /app

RUN npm install -g pnpm@9

COPY ui/package.json ui/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY ui ./

ENV VITE_API_BASE=/api
RUN pnpm build

############################################################################################
# 5. RUNTIME
############################################################################################
FROM alpine:latest AS runtime

WORKDIR /

RUN apk add --no-cache ca-certificates

COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/pentaract /pentaract
COPY --from=ui /app/dist /ui

EXPOSE 3000

ENV RUST_LOG=info

ENTRYPOINT ["/pentaract"]
