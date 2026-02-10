#!/bin/bash

echo "========================================================================="
echo "Starting Keycloak for DigitalOcean App Platform"
echo "Keycloak Version: $(cat /opt/keycloak/version.txt 2>/dev/null || echo 'Unknown')"
echo "========================================================================="

# Set default values
export PORT=${PORT:-8080}

# Handle legacy environment variables by converting them to modern KC_* format
if [ -n "$KEYCLOAK_USER" ] && [ -z "$KC_BOOTSTRAP_ADMIN_USERNAME" ]; then
    export KC_BOOTSTRAP_ADMIN_USERNAME="$KEYCLOAK_USER"
    echo "Converted KEYCLOAK_USER to KC_BOOTSTRAP_ADMIN_USERNAME"
fi

if [ -n "$KEYCLOAK_PASSWORD" ] && [ -z "$KC_BOOTSTRAP_ADMIN_PASSWORD" ]; then
    export KC_BOOTSTRAP_ADMIN_PASSWORD="$KEYCLOAK_PASSWORD"
    echo "Converted KEYCLOAK_PASSWORD to KC_BOOTSTRAP_ADMIN_PASSWORD"
fi

if [ -n "$PROXY_ADDRESS_FORWARDING" ] && [ "$PROXY_ADDRESS_FORWARDING" = "true" ] && [ -z "$KC_PROXY" ]; then
    export KC_PROXY="edge"
    echo "Converted PROXY_ADDRESS_FORWARDING to KC_PROXY=edge"
fi

# Parse DATABASE_URL if provided (Heroku/DigitalOcean format)
if [ -n "$DATABASE_URL" ]; then
    echo "Found database configuration in DATABASE_URL"

    # Set Keycloak database configuration - let Keycloak handle URL parsing
    export KC_DB="postgres"

    # Modern Keycloak can handle PostgreSQL URLs directly, but needs JDBC format
    if [[ $DATABASE_URL =~ ^postgres(ql)?://([^:]+):([^@]+)@([^:]+):([0-9]+)/(.+)$ ]]; then
        DB_USERNAME="${BASH_REMATCH[2]}"
        DB_PASSWORD="${BASH_REMATCH[3]}"
        DB_HOST="${BASH_REMATCH[4]}"
        DB_PORT="${BASH_REMATCH[5]}"
        DB_NAME="${BASH_REMATCH[6]}"

        # Extract query parameters (like ?sslmode=require)
        if [[ $DB_NAME =~ ^([^?]+)(.*)$ ]]; then
            DB_NAME="${BASH_REMATCH[1]}"
            DB_PARAMS="${BASH_REMATCH[2]}"
        fi

        # Set Keycloak database configuration in JDBC format
        export KC_DB_URL="jdbc:postgresql://$DB_HOST:$DB_PORT/$DB_NAME$DB_PARAMS"
        export KC_DB_USERNAME="$DB_USERNAME"
        export KC_DB_PASSWORD="$DB_PASSWORD"

        echo "Configured PostgreSQL JDBC: $KC_DB_URL"
        echo "Database user: $DB_USERNAME"
    else
        echo "WARNING: Could not parse DATABASE_URL format: $DATABASE_URL"
    fi
fi

# Set production-ready defaults if not in development
if [ -z "$KC_DB" ]; then
    echo "No database configured, using embedded H2 (development only)"
    export KC_DB="dev-file"
fi

# Configure for App Platform deployment
export KC_HTTP_PORT="$PORT"
export KC_HTTP_ENABLED="true"

# Don't override hostname settings - let environment variables take precedence
# export KC_HOSTNAME_STRICT="false"
# export KC_HOSTNAME_STRICT_HTTPS="false"

# Set proxy mode for load balancers (DigitalOcean App Platform) - only if not already set
if [ -z "$KC_PROXY" ]; then
    export KC_PROXY="edge"
fi

# Health check endpoints - only if not already set
if [ -z "$KC_HEALTH_ENABLED" ]; then
    export KC_HEALTH_ENABLED="true"
fi

# Always use production mode if we have a proper database
if [ -n "$DATABASE_URL" ] && [ "$KC_DB" = "postgres" ]; then
    STARTUP_MODE="start"
    echo "Starting in production mode with PostgreSQL"
else
    STARTUP_MODE="start-dev"
    echo "Starting in development mode"
fi

echo "========================================================================="
echo "Configuration Summary:"
echo "- Port: $PORT"
echo "- Database: ${KC_DB:-not set}"
echo "- Proxy mode: ${KC_PROXY:-not set}"
echo "- Admin user: ${KC_BOOTSTRAP_ADMIN_USERNAME:-not set}"
echo "- Startup mode: $STARTUP_MODE"
echo "========================================================================="

# Start Keycloak
exec /opt/keycloak/bin/kc.sh $STARTUP_MODE
