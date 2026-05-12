FROM harbor.home/docker/steamcmd/steamcmd:ubuntu-24
# Harbor proxy for docker.io/steamcmd/steamcmd:ubuntu-24

ENV VALHEIM_DIR=/opt/valheim \
    VALHEIM_PORT=2456 \
    VALHEIM_PORT_END=2458

# Install OS packages before COPY so edits to scripts keep this layer cached.
# BuildKit cache mounts reuse apt metadata and .deb files across builds on the same node.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    mkdir -p "${VALHEIM_DIR}" \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        unzip \
        jq \
        rsync \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /home/steam/entrypoint.sh
COPY download-plugins.sh /home/steam/download-plugins.sh
COPY plugin-list /home/steam/plugin-list

RUN chmod +x /home/steam/entrypoint.sh \
    && chmod +x /home/steam/download-plugins.sh

EXPOSE 2456/udp 2457/udp 2458/udp

ENTRYPOINT ["/home/steam/entrypoint.sh"]
CMD []
