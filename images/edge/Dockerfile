FROM dc-base:1
RUN apt-get update && apt-get install -y --no-install-recommends \
      strongswan-starter libstrongswan-standard-plugins nftables snmpd \
    && rm -rf /var/lib/apt/lists/*
COPY edge/startup.sh /startup.sh
RUN chmod +x /startup.sh
ENTRYPOINT ["/startup.sh"]
