#!/usr/bin/env bash
set -euo pipefail

# Basic Postgres bootstrap matching docker-compose defaults.
# - Creates role + database if they do not already exist.
# - Grants ownership to the role so `DATABASE_URL=postgres://user:pass@host:port/db` works.
# Environment overrides:
#   POSTGRES_DB (default: scribal)
#   POSTGRES_USER (default: scribal)
#   POSTGRES_PASSWORD (default: scribal)
#   POSTGRES_HOST (default: localhost; automatically switches to the local unix socket if no superuser password is provided)
#   POSTGRES_PORT (default: 5432)
#   POSTGRES_SUPERUSER (default: postgres)
#   POSTGRES_SUPERUSER_PASSWORD (optional, exported to PGPASSWORD)

if ! command -v psql >/dev/null 2>&1; then
  echo "[!] psql not found. Install PostgreSQL client tools before running this script." >&2
  exit 1
fi

DB_NAME="${POSTGRES_DB:-scribal}"
DB_USER="${POSTGRES_USER:-scribal}"
DB_PASSWORD="${POSTGRES_PASSWORD:-scribal}"
DB_HOST="${POSTGRES_HOST:-localhost}"
DB_PORT="${POSTGRES_PORT:-5432}"
SUPERUSER="${POSTGRES_SUPERUSER:-postgres}"
SUPERUSER_PASSWORD="${POSTGRES_SUPERUSER_PASSWORD:-}"

# On Ubuntu the postgres superuser typically authenticates via peer over the unix socket and has no password.
# If no password was provided and we're pointing at localhost, prefer the socket path and run psql as that OS user.
if [[ -z "$SUPERUSER_PASSWORD" && "$DB_HOST" == "localhost" ]]; then
  if [[ -d "/var/run/postgresql" ]]; then
    DB_HOST="/var/run/postgresql"
  fi
fi

PSQL_CMD=(psql)
if [[ -z "$SUPERUSER_PASSWORD" && "$(id -un)" != "$SUPERUSER" ]]; then
  if command -v sudo >/dev/null 2>&1; then
    PSQL_CMD=(sudo -u "$SUPERUSER" psql)
  else
    echo "[!] No superuser password provided and sudo is unavailable to switch to $SUPERUSER." >&2
    echo "    Either rerun this script as the $SUPERUSER OS user or set POSTGRES_SUPERUSER_PASSWORD." >&2
    exit 1
  fi
fi

PSQL_ARGS=(
  --dbname postgres
  --set db_name="$DB_NAME"
  --set db_user="$DB_USER"
  --set db_password="$DB_PASSWORD"
)

if [[ -n "$DB_HOST" ]]; then
  PSQL_ARGS+=(--host "$DB_HOST")
fi
if [[ -n "$DB_PORT" ]]; then
  PSQL_ARGS+=(--port "$DB_PORT")
fi
PSQL_ARGS+=(--username "$SUPERUSER")

if [[ -n "$SUPERUSER_PASSWORD" ]]; then
  export PGPASSWORD="$SUPERUSER_PASSWORD"
fi

printf '[+] Connecting as %s@%s:%s\n' "$SUPERUSER" "$DB_HOST" "$DB_PORT"

"${PSQL_CMD[@]}" "${PSQL_ARGS[@]}" <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'db_user') THEN
    EXECUTE format('CREATE ROLE %I WITH LOGIN PASSWORD %L;', :'db_user', :'db_password');
    RAISE NOTICE 'Created role %', :'db_user';
  ELSE
    EXECUTE format('ALTER ROLE %I WITH LOGIN PASSWORD %L;', :'db_user', :'db_password');
    RAISE NOTICE 'Role % already exists; password updated.', :'db_user';
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_database WHERE datname = :'db_name') THEN
    EXECUTE format('CREATE DATABASE %I OWNER %I;', :'db_name', :'db_user');
    RAISE NOTICE 'Created database % with owner %', :'db_name', :'db_user';
  ELSE
    EXECUTE format('ALTER DATABASE %I OWNER TO %I;', :'db_name', :'db_user');
    RAISE NOTICE 'Database % already exists; ownership ensured.', :'db_name';
  END IF;
END
$$;

GRANT ALL PRIVILEGES ON DATABASE :"db_name" TO :"db_user";
SQL

if [[ -n "$SUPERUSER_PASSWORD" ]]; then
  unset PGPASSWORD
fi

DISPLAY_HOST="$DB_HOST"
if [[ "$DISPLAY_HOST" == "/var/run/postgresql" ]]; then
  DISPLAY_HOST="localhost"
fi

printf '[✓] Postgres role %s and database %s are ready.\n' "$DB_USER" "$DB_NAME"
printf '    DATABASE_URL=postgres://%s:%s@%s:%s/%s\n' "$DB_USER" "$DB_PASSWORD" "$DISPLAY_HOST" "$DB_PORT" "$DB_NAME"
