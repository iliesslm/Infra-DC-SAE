FROM dc-base:1
RUN apt-get update && apt-get install -y --no-install-recommends frr snmpd \
    && rm -rf /var/lib/apt/lists/*
COPY router/startup.sh /startup.sh
RUN chmod +x /startup.sh
ENTRYPOINT ["/startup.sh"]
