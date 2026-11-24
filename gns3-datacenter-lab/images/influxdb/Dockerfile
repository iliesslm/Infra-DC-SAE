FROM influxdb:1.8
RUN apt-get update && apt-get install -y --no-install-recommends iproute2 \
    && rm -rf /var/lib/apt/lists/*
COPY common/netinit.sh /usr/local/bin/netinit.sh
COPY influxdb/entrypoint.sh /dc-entrypoint.sh
RUN chmod +x /dc-entrypoint.sh /usr/local/bin/netinit.sh
ENV INFLUXDB_DB=telegraf INFLUXDB_REPORTING_DISABLED=true INFLUXDB_HTTP_AUTH_ENABLED=false
ENTRYPOINT ["/dc-entrypoint.sh"]
CMD ["influxd"]
