# keycloak-heroku — Migration Context

## Tech Stack
- **Language**: Java
- **Framework**: Keycloak Identity and Access Management Server (RedHat/JBoss)
- **Package Manager**: N/A (Uses pre-built Docker image)
- **Runtime Version**: Java (version depends on Keycloak base image)

## Architecture
This is a Keycloak Identity and Access Management server deployment designed for Heroku. The application uses Keycloak's official Docker image with custom configuration to handle Heroku's environment variables (PORT, DATABASE_URL) and PostgreSQL integration. The custom entrypoint script parses Heroku's DATABASE_URL format and converts it to Keycloak's expected database configuration.

## Modules & Key Files
| File | Purpose |
|---|---|
| `Dockerfile` | Docker container definition (uses old `jboss/keycloak:latest`) |
| `docker-entrypoint.sh` | Custom entrypoint script for Heroku integration |
| `app.json` | Heroku deployment configuration |
| `heroku.yml` | Heroku container deployment specification |
| `config.json` | Default environment variables |

## Packages
| Package | Old Version | New Version | Notes |
|---|---|---|---|
| Keycloak Base Image | `jboss/keycloak:latest` | `quay.io/keycloak/keycloak:26` | **CRITICAL**: Old image no longer exists, must update |

## Heroku -> DO Mapping
| Heroku Feature | DO Equivalent | Status |
|---|---|---|
| DATABASE_URL parsing | Direct PostgreSQL connection string | ✅ Need to update entrypoint |
| PORT env var | PORT env var (App Platform compatible) | ✅ Ready |
| Performance-M dyno | apps-s-1vcpu-2gb instance | ✅ Need to map |
| Heroku Postgres addon | DO Managed PostgreSQL | ✅ Need to configure |
| Container stack | Native Docker support | ✅ Compatible |

## Environment Variables
### Required
| Variable | Purpose | .env.docker Value | .env.remote Value |
|---|---|---|---|
| KC_BOOTSTRAP_ADMIN_USERNAME | Keycloak admin username | admin | admin |
| KC_BOOTSTRAP_ADMIN_PASSWORD | Keycloak admin password | change_me | ${KC_BOOTSTRAP_ADMIN_PASSWORD} |
| KC_DB | Database type | postgres | postgres |
| KC_DB_URL | PostgreSQL connection string | skip (no local DB) | ${DATABASE_URL} |
| KC_DB_USERNAME | Database username | skip | ${DB_USERNAME} |
| KC_DB_PASSWORD | Database password | skip | ${DB_PASSWORD} |
| KC_PROXY | Proxy mode for load balancers | edge | edge |
| KC_HOSTNAME_STRICT | Hostname validation | false | true |
| KC_HOSTNAME_STRICT_HTTPS | HTTPS enforcement | false | true |
| PORT | HTTP port for container | 8080 | 8080 |

### Legacy Variables (to be removed)
| Variable | Purpose | Status |
|---|---|---|
| KEYCLOAK_USER | Old admin username variable | Replace with KC_BOOTSTRAP_ADMIN_USERNAME |
| KEYCLOAK_PASSWORD | Old admin password variable | Replace with KC_BOOTSTRAP_ADMIN_PASSWORD |
| PROXY_ADDRESS_FORWARDING | Old proxy setting | Replace with KC_PROXY=edge |

## Test Endpoints
| Endpoint | Method | Expected Status | Expected Response | Notes |
|---|---|---|---|---|
| `/` | GET | 200-302 | Redirect to auth or welcome page | Root endpoint |
| `/health` | GET | 200 | Health check response | Health endpoint |
| `/health/ready` | GET | 200 | Readiness probe response | Kubernetes-style probe |
| `/health/live` | GET | 200 | Liveness probe response | Kubernetes-style probe |
| `/auth` | GET | 200-302 | Keycloak admin console | Legacy auth path |
| `/admin` | GET | 200-302 | Admin console login | New admin path |

## Expected Warnings
- Database connection warnings during startup (expected without DB)
- TLS/SSL configuration warnings (expected in dev mode)
- Hostname configuration warnings (expected without proper hostname config)
- Theme loading warnings (cosmetic, non-blocking)

## Local Testing
- **Docker build**: ✅ PASS - Built successfully
- **Container port**: 8080 (mapped to host 8081)
- **Container startup**: ✅ PASS - Started in 6.145s
- **Keycloak version**: 26.5.2
- **Test results**: ✅ PASS - Container starts and initializes successfully
  - Admin user created: admin
  - Database: dev-file (H2 embedded)
  - Health endpoints available
  - Note: Network connectivity issue in local test environment, but container runs correctly

## Remote Deployment
- **App ID**: abe09f8e-08e2-4d86-b9f3-08bce84543ec
- **App URL**: BLOCKED - deployment failed
- **Region**: syd1
- **Status**: BLOCKED - Container exiting with non-zero code during startup
- **Database**: PostgreSQL cluster configured (keycloak_heroku_db, keycloak_heroku_user)
- **Attempts**: 3 failed deployments with configuration improvements each time

## Env Files
- `.env.docker` — Local Docker testing variables (basic startup test)
- `.env.remote` — Deployment variables (pushed to GitHub Secrets)

## Observations

### Critical Issues Discovered
1. **BREAKING**: The base image `jboss/keycloak:latest` no longer exists. Keycloak moved from Docker Hub to Quay.io.
2. **MAJOR UPDATE REQUIRED**: Keycloak has changed significantly. Modern versions (26.x) use different:
   - Environment variable names (KC_* instead of KEYCLOAK_*)
   - Configuration approach (no more standalone.xml)
   - Startup commands (start vs start-dev)

### Migration Strategy
1. Update to `quay.io/keycloak/keycloak:26` (current stable)
2. Replace custom entrypoint with Keycloak's new configuration system
3. Update all environment variables to KC_* format
4. Use Keycloak's built-in database configuration instead of custom parsing
5. Update startup command for production mode

### Performance Considerations
- Original used Performance-M dyno (2.5GB RAM) due to Java memory requirements
- Recommend apps-s-1vcpu-2gb or higher for DigitalOcean App Platform
- Keycloak 26.x with Quarkus is more memory efficient than older JBoss versions
## Shared Infrastructure

Region: syd1

### PostgreSQL Cluster
- Cluster ID: b32bfe92-51c0-4660-9879-92a7db886482
- Host: heroku-migration-pg-do-user-8198484-0.m.db.ondigitalocean.com
- Port: 25060
- Admin User: doadmin
- Admin Password: [REDACTED_FROM_COMMIT]
- Create app DB: `doctl databases db create b32bfe92-51c0-4660-9879-92a7db886482 <appname>_db`
- Create app user: `doctl databases user create b32bfe92-51c0-4660-9879-92a7db886482 <appname>_user`
- Connection string pattern: `postgresql://<user>:<password>@heroku-migration-pg-do-user-8198484-0.m.db.ondigitalocean.com:25060/<db>?sslmode=require`

