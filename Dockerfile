# Use an Ubuntu base with minimal extra baggage
FROM docker.io/steamcmd/steamcmd:ubuntu-24

ENV VALHEIM_DIR=/opt/valheim \
    VALHEIM_PORT=2456 \
    VALHEIM_PORT_END=2458

RUN mkdir -p ${VALHEIM_DIR}

COPY entrypoint.sh /home/steam/entrypoint.sh 
COPY download-plugins.sh /home/steam/download-plugins.sh
COPY plugin-list /home/steam/plugin-list

RUN chmod +x /home/steam/entrypoint.sh \
    && chmod +x /home/steam/download-plugins.sh \
    && mkdir -p ${VALHEIM_DIR} \
    && apt update \
    && apt install -y \
        curl \
        vim \
        unzip \
        jq

EXPOSE 2456/udp 2457/udp 2458/udp

ENTRYPOINT ["/home/steam/entrypoint.sh"]
CMD []

