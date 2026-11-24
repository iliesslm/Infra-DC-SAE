FROM dc-base:1
RUN apt-get update && apt-get install -y --no-install-recommends iperf3 netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*
COPY client/startup.sh /startup.sh
RUN chmod +x /startup.sh
ENTRYPOINT ["/startup.sh"]
