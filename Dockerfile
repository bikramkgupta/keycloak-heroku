FROM quay.io/keycloak/keycloak:latest

# Copy custom entrypoint for DigitalOcean App Platform
COPY docker-entrypoint.sh /opt/keycloak/bin/

# Set proper permissions
USER root
RUN chmod +x /opt/keycloak/bin/docker-entrypoint.sh
USER keycloak

# Expose port (App Platform will set PORT env var)
EXPOSE 8080

ENTRYPOINT ["/opt/keycloak/bin/docker-entrypoint.sh"]

