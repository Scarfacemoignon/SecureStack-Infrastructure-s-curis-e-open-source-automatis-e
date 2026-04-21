FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    suricata \
    suricata-update \
    # suricata-update : outil de mise à jour des règles Emerging Threats
    iproute2 \
    tcpdump \
    && rm -rf /var/lib/apt/lists/*

# Mise à jour des règles Emerging Threats (communautaires)
RUN suricata-update update-sources && \
    suricata-update enable-source et/open && \
    suricata-update

COPY suricata.yaml /etc/suricata/suricata.yaml

# Logs EVE JSON (consommés par Wazuh)
VOLUME ["/var/log/suricata"]

CMD ["suricata", "-c", "/etc/suricata/suricata.yaml", "--af-packet"]
