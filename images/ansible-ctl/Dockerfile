FROM dc-base:1
RUN apt-get update && apt-get install -y --no-install-recommends ansible snmp netcat-openbsd python3-yaml \
    && rm -rf /var/lib/apt/lists/*
COPY common/dc_lab /root/.ssh/id_ed25519
COPY ansible /ansible
COPY tests /tests
RUN chmod 600 /root/.ssh/id_ed25519 && chmod +x /tests/*.sh
WORKDIR /ansible
COPY ansible-ctl/startup.sh /startup.sh
RUN chmod +x /startup.sh
ENTRYPOINT ["/startup.sh"]
