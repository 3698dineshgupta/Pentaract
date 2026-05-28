############################################################################################
####  SERVER
############################################################################################

FROM clux/muslrust:stable AS chef

USER root

RUN cargo install cargo-chef

WORKDIR /app

FROM chef AS planner

COPY ./pentaract .

RUN cargo chef prepare --recipe-path recipe.json

FROM chef AS builder

COPY --from=planner /app/recipe.json recipe.json

RUN cargo chef cook --release --target x86_64-unknown-linux-musl --recipe-path recipe.json

COPY ./pentaract .

RUN cargo build --target x86_64-unknown-linux-musl --release

############################################################################################
####  UI
############################################################################################

FROM node:22-slim AS ui

WORKDIR /app

COPY ./ui .

RUN npm install -g pnpm

RUN pnpm config set ignore-scripts false

RUN pnpm install

ENV VITE_API_BASE=/api

RUN pnpm run build

############################################################################################
####  RUNNING
############################################################################################

FROM scratch AS runtime

COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/pentaract /

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

COPY --from=ui /app/dist /ui

ENTRYPOINT ["/pentaract"]
