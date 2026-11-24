FROM telegraf:1.30
RUN apt-get update && apt-get install -y --no-install-recommends iproute2 \
    && rm -rf /var/lib/apt/lists/*
COPY common/netinit.sh /usr/local/bin/netinit.sh
COPY telegraf/entrypoint.sh /dc-entrypoint.sh
COPY telegraf/telegraf.conf /etc/telegraf/telegraf.conf
RUN chmod +x /dc-entrypoint.sh /usr/local/bin/netinit.sh
ENTRYPOINT ["/dc-entrypoint.sh"]
CMD ["telegraf"]
