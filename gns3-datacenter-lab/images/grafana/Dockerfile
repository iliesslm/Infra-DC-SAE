FROM grafana/grafana-oss:10.4.2
USER root
COPY common/netinit.sh /usr/local/bin/netinit.sh
COPY grafana/entrypoint.sh /dc-entrypoint.sh
COPY grafana/provisioning /etc/grafana/provisioning
COPY grafana/dashboards /var/lib/grafana/dashboards
RUN chmod +x /dc-entrypoint.sh /usr/local/bin/netinit.sh
ENV GF_AUTH_ANONYMOUS_ENABLED=true GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer \
    GF_SECURITY_ADMIN_USER=admin GF_SECURITY_ADMIN_PASSWORD=admin \
    GF_ANALYTICS_REPORTING_ENABLED=false GF_ANALYTICS_CHECK_FOR_UPDATES=false \
    GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/var/lib/grafana/dashboards/dc-lab.json
ENTRYPOINT ["/dc-entrypoint.sh"]
