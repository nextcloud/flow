# SPDX-FileCopyrightText: 2024 Nextcloud GmbH and Nextcloud contributors
# SPDX-License-Identifier: MIT
ARG DEBIAN_IMAGE=debian:bookworm-slim
ARG RUST_IMAGE=rust:1.80-slim-bookworm
ARG PYTHON_IMAGE=python:3.12-slim

FROM ${RUST_IMAGE} AS rust_base

RUN apt-get update && apt-get install -y git libssl-dev pkg-config npm

RUN apt-get -y update \
    && apt-get install -y \
    curl nodejs

RUN rustup component add rustfmt

RUN CARGO_NET_GIT_FETCH_WITH_CLI=true cargo install cargo-chef --version ^0.1
RUN cargo install sccache --version ^0.8
ENV RUSTC_WRAPPER=sccache SCCACHE_DIR=/backend/sccache

WORKDIR /windmill

ENV SQLX_OFFLINE=true
# ENV CARGO_INCREMENTAL=1

FROM node:20-alpine as frontend

# install dependencies
WORKDIR /frontend
COPY ./frontend/package.json ./frontend/package-lock.json ./
RUN npm ci

# Copy all local files into the image.
COPY frontend .
RUN mkdir /backend
COPY /backend/windmill-api/openapi.yaml /backend/windmill-api/openapi.yaml
COPY /openflow.openapi.yaml /openflow.openapi.yaml
COPY /backend/windmill-api/build_openapi.sh /backend/windmill-api/build_openapi.sh

RUN cd /backend/windmill-api && . ./build_openapi.sh
COPY /backend/parsers/windmill-parser-wasm/pkg/ /backend/parsers/windmill-parser-wasm/pkg/
COPY /typescript-client/docs/ /frontend/static/tsdocs/

RUN npm run generate-backend-client
RUN sed -i "s|BASE: '/api'|BASE: '/index.php/apps/app_api/proxy/flow/api'|" /frontend/src/lib/gen/core/OpenAPI.ts
ENV NODE_OPTIONS "--max-old-space-size=8192"
ARG VITE_BASE_URL ""
RUN npm run build

FROM scratch AS export_frontend
COPY --from=frontend /frontend/build/ /

FROM rust_base AS planner

COPY ./openflow.openapi.yaml /openflow.openapi.yaml
COPY ./backend ./

RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=$SCCACHE_DIR,sharing=locked \
    CARGO_NET_GIT_FETCH_WITH_CLI=true cargo chef prepare --recipe-path recipe.json

FROM rust_base AS builder
ARG features=""

COPY --from=planner /windmill/recipe.json recipe.json

RUN apt-get update && apt-get install -y libxml2-dev=2.9.* libxmlsec1-dev=1.2.* clang=1:14.0-55.* libclang-dev=1:14.0-55.* cmake=3.25.* && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=$SCCACHE_DIR,sharing=locked \
    CARGO_NET_GIT_FETCH_WITH_CLI=true RUST_BACKTRACE=1 cargo chef cook --release --features "$features" --recipe-path recipe.json

COPY ./openflow.openapi.yaml /openflow.openapi.yaml
COPY ./backend ./

RUN mkdir -p /frontend

COPY --from=frontend /frontend/build /frontend/build
COPY --from=frontend /backend/windmill-api/openapi-deref.yaml ./windmill-api/openapi-deref.yaml
COPY .git/ .git/

RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=$SCCACHE_DIR,sharing=locked \
    CARGO_NET_GIT_FETCH_WITH_CLI=true cargo build --release --features "$features"


FROM ${PYTHON_IMAGE}

ARG TARGETPLATFORM
ARG POWERSHELL_VERSION=7.3.5
ARG POWERSHELL_DEB_VERSION=7.3.5-1
ARG KUBECTL_VERSION=1.28.7
ARG HELM_VERSION=3.14.3
ARG GO_VERSION=1.22.5
ARG APP=/usr/src/app
ARG WITH_POWERSHELL=true
ARG WITH_KUBECTL=true
ARG WITH_HELM=true
ARG WITH_GIT=true

RUN apt-get update \
    && apt-get install -y ca-certificates wget curl jq unzip build-essential unixodbc xmlsec1  software-properties-common \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN if [ "$WITH_GIT" = "true" ]; then \
    apt-get update  -y \
    && apt-get install -y git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*; \
    else echo 'Building the image without git'; fi;

RUN if [ "$WITH_POWERSHELL" = "true" ]; then \
    if [ "$TARGETPLATFORM" = "linux/amd64" ]; then apt-get update -y && apt install libicu-dev -y && wget -O 'pwsh.deb' "https://github.com/PowerShell/PowerShell/releases/download/v${POWERSHELL_VERSION}/powershell_${POWERSHELL_DEB_VERSION}.deb_amd64.deb" && apt-get clean \
    && rm -rf /var/lib/apt/lists/* && \
    dpkg --install 'pwsh.deb' && \
    rm 'pwsh.deb'; \
    elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then apt-get update -y && apt install libicu-dev -y && wget -O powershell.tar.gz "https://github.com/PowerShell/PowerShell/releases/download/v${POWERSHELL_VERSION}/powershell-${POWERSHELL_VERSION}-linux-arm64.tar.gz" && apt-get clean \
    && rm -rf /var/lib/apt/lists/* && \
    mkdir -p /opt/microsoft/powershell/7 && \
    tar zxf powershell.tar.gz -C /opt/microsoft/powershell/7 && \
    chmod +x /opt/microsoft/powershell/7/pwsh && \
    ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh && \
    rm powershell.tar.gz; \
    else echo 'Could not install pwshell, not on amd64 or arm64'; fi;  \
    else echo 'Building the image without powershell'; fi

RUN if [ "$WITH_HELM" = "true" ]; then \
    arch="$(dpkg --print-architecture)"; arch="${arch##*-}"; \
    wget "https://get.helm.sh/helm-v${HELM_VERSION}-linux-$arch.tar.gz" && \
    tar -zxvf "helm-v${HELM_VERSION}-linux-$arch.tar.gz"  && \
    mv linux-$arch/helm /usr/local/bin/helm &&\
    chmod +x /usr/local/bin/helm; \
    else echo 'Building the image without helm'; fi

RUN if [ "$WITH_KUBECTL" = "true" ]; then \
    arch="$(dpkg --print-architecture)"; arch="${arch##*-}"; \
    curl -LO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/$arch/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl; \
    else echo 'Building the image without kubectl'; fi


RUN set -eux; \
    arch="$(dpkg --print-architecture)"; arch="${arch##*-}"; \
    case "$arch" in \
    "amd64") \
    targz="go${GO_VERSION}.linux-amd64.tar.gz"; \
    ;; \
    "arm64") \
    targz="go${GO_VERSION}.linux-arm64.tar.gz"; \
    ;; \
    "armhf") \
    targz="go${GO_VERSION}.linux-armv6l.tar.gz"; \
    ;; \
    *) echo >&2 "error: unsupported architecture '$arch' (likely packaging update needed)"; exit 1 ;; \
    esac; \
    wget "https://golang.org/dl/$targz" -nv && tar -C /usr/local -xzf "$targz" && rm "$targz";

ENV PATH="${PATH}:/usr/local/go/bin"
ENV GO_PATH=/usr/local/go/bin/go

RUN curl -sL https://deb.nodesource.com/setup_20.x | bash -
RUN apt-get -y update && apt-get install -y curl nodejs awscli && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# go build is slower the first time it is ran, so we prewarm it in the build
RUN mkdir -p /tmp/gobuildwarm && cd /tmp/gobuildwarm && go mod init gobuildwarm && printf "package foo\nimport (\"fmt\")\nfunc main() { fmt.Println(42) }" > warm.go && go mod tidy && go build -x && rm -rf /tmp/gobuildwarm

ENV TZ=Etc/UTC

RUN /usr/local/bin/python3 -m pip install pip-tools

COPY --from=builder /frontend/build /static_frontend
COPY --from=builder /windmill/target/release/windmill ${APP}/windmill

COPY --from=denoland/deno:1.46.3 --chmod=755 /usr/bin/deno /usr/bin/deno

COPY --from=oven/bun:1.1.25 /usr/local/bin/bun /usr/bin/bun

COPY --from=php:8.3.7-cli /usr/local/bin/php /usr/bin/php
COPY --from=composer:2.7.6 /usr/bin/composer /usr/bin/composer

# add the docker client to call docker from a worker if enabled
COPY --from=docker:dind /usr/local/bin/docker /usr/local/bin/

ENV RUSTUP_HOME="/usr/local/rustup"
ENV CARGO_HOME="/usr/local/cargo"

WORKDIR ${APP}

RUN ln -s ${APP}/windmill /usr/local/bin/windmill

COPY ./frontend/src/lib/hubPaths.json ${APP}/hubPaths.json

RUN windmill cache ${APP}/hubPaths.json && rm ${APP}/hubPaths.json && chmod -R 777 /tmp/windmill

EXPOSE 8000

RUN apt-get update && \
    apt-get install -y \
    curl nodejs sudo wget procps nano && \
    rm -rf /var/lib/apt/lists/*

# HaRP: download and install FRP client
RUN set -ex; \
    ARCH=$(uname -m); \
    if [ "$ARCH" = "aarch64" ]; then \
      FRP_URL="https://raw.githubusercontent.com/nextcloud/HaRP/main/exapps_dev/frp_0.61.1_linux_arm64.tar.gz"; \
    else \
      FRP_URL="https://raw.githubusercontent.com/nextcloud/HaRP/main/exapps_dev/frp_0.61.1_linux_amd64.tar.gz"; \
    fi; \
    echo "Downloading FRP client from $FRP_URL"; \
    curl -L "$FRP_URL" -o /tmp/frp.tar.gz; \
    tar -C /tmp -xzf /tmp/frp.tar.gz; \
    mv /tmp/frp_0.61.1_linux_* /tmp/frp; \
    cp /tmp/frp/frpc /usr/local/bin/frpc; \
    chmod +x /usr/local/bin/frpc; \
    rm -rf /tmp/frp /tmp/frp.tar.gz

COPY ex_app_scripts/common_pgsql.sh /ex_app_scripts/common_pgsql.sh
COPY ex_app_scripts/install_pgsql.sh /ex_app_scripts/install_pgsql.sh
COPY ex_app_scripts/init_pgsql.sh /ex_app_scripts/init_pgsql.sh
COPY ex_app_scripts/set_workers_num.sh /ex_app_scripts/set_workers_num.sh
COPY ex_app_scripts/entrypoint.sh /ex_app_scripts/entrypoint.sh

RUN chmod +x /ex_app_scripts/*.sh && /ex_app_scripts/install_pgsql.sh && rm /ex_app_scripts/install_pgsql.sh

COPY requirements.txt /ex_app_requirements.txt

ADD ex_app/cs[s] /ex_app/css
ADD ex_app/im[g] /ex_app/img
ADD ex_app/j[s] /ex_app/js
ADD ex_app/l10[n] /ex_app/l10n
ADD ex_app/li[b] /ex_app/lib

RUN python3 -m pip install -r /ex_app_requirements.txt
RUN chmod +x /ex_app/lib/main.py

CMD ["/bin/sh", "/ex_app_scripts/entrypoint.sh", "/ex_app/lib/main.py", "windmill"]
