# Image de base commune : SSH (cle uniquement) + Python (pour Ansible) + outils reseau
FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      openssh-server python3 iproute2 iputils-ping tcpdump procps ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
COPY common/netinit.sh /usr/local/bin/netinit.sh
COPY common/authorized_keys /root/.ssh/authorized_keys
RUN chmod +x /usr/local/bin/netinit.sh \
 && chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys \
 && mkdir -p /run/sshd \
 && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/; s/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
