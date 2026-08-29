# build (also how to bump pi or memsearch: change the ARG default, or override here):
# docker build --build-arg PI_UID="$(id -u)" --build-arg PI_GID="$(id -g)" \
#   --build-arg PI_HOME="$HOME" --build-arg PI_VERSION=0.84.4 -t local/pi:latest .
FROM node:24-bookworm-slim

ARG PI_UID=1000
ARG PI_GID=1000
ARG PI_HOME=/home/pi
ARG MEMSEARCH_VERSION=0.4.13
ARG PI_VERSION=0.84.4

RUN groupmod --gid "$PI_GID" node \
 && usermod --uid "$PI_UID" --gid "$PI_GID" \
      --home "$PI_HOME" --move-home node \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      bash ca-certificates curl file git jq less \
      make g++ python3 python3-pip procps ripgrep libnotify-bin gh \
      cmake clang clang-format ssh \
 && rm -rf /var/lib/apt/lists/* \
 && python3 -m pip install --no-cache-dir --break-system-packages uv \
 && UV_TOOL_DIR=/opt/uv/tools UV_TOOL_BIN_DIR=/usr/local/bin \
      uv tool install --force "memsearch[onnx]==${MEMSEARCH_VERSION}" \
 && HOME="$PI_HOME" memsearch config set embedding.provider onnx \
 && npm install -g --ignore-scripts \
      @earendil-works/pi-coding-agent@"$PI_VERSION" \
 && chown -R "$PI_UID:$PI_GID" "$PI_HOME"

COPY entrypoint.sh /usr/local/bin/pi-entrypoint
RUN chmod 755 /usr/local/bin/pi-entrypoint

# Drop a corporate root CA in here to trust it; ca-certificates is already installed
# by the RUN above, so only the refresh below is needed.
# COPY yandex-internal-root-ca/YandexInternalRootCA.crt /usr/local/share/ca-certificates/YandexInternalRootCA.crt

RUN update-ca-certificates --fresh \
 && test -s /etc/ssl/certs/ca-certificates.crt

ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

USER node
ENV HOME=${PI_HOME}
ENV PATH=/usr/local/bin:${PATH}
WORKDIR /workspace
ENTRYPOINT ["pi-entrypoint"]
