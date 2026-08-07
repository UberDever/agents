FROM node:24-bookworm-slim

ARG PI_UID=1000
ARG PI_GID=1000
ARG PI_HOME=/home/pi

RUN groupmod --gid "$PI_GID" node \
 && usermod --uid "$PI_UID" --gid "$PI_GID" \
      --home "$PI_HOME" --move-home node \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      bash ca-certificates curl file git jq less \
      make g++ python3 procps ripgrep \
 && rm -rf /var/lib/apt/lists/* \
 && npm install -g --ignore-scripts \
      @earendil-works/pi-coding-agent@0.82.0 \
 && chown -R "$PI_UID:$PI_GID" "$PI_HOME"

USER node
ENV HOME=${PI_HOME}
WORKDIR /workspace
ENTRYPOINT ["pi"]
