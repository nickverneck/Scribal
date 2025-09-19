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
  --set ON_ERROR_STOP=1
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

escape_literal() {
  local value="$1"
  printf "'%s'" "${value//"'"/"''"}"
}

escape_identifier() {
  local value="$1"
  printf '"%s"' "${value//"\""/"\"\""}"
}

run_psql() {
  "${PSQL_CMD[@]}" "${PSQL_ARGS[@]}" --command "$1" >/dev/null
}

role_exists=$("${PSQL_CMD[@]}" "${PSQL_ARGS[@]}" -tAc "SELECT 1 FROM pg_roles WHERE rolname = $(escape_literal "$DB_USER")") || true
if [[ -z "$role_exists" ]]; then
  run_psql "CREATE ROLE $(escape_identifier "$DB_USER") WITH LOGIN PASSWORD $(escape_literal "$DB_PASSWORD");"
  echo "[+] Created role $DB_USER"
else
  run_psql "ALTER ROLE $(escape_identifier "$DB_USER") WITH LOGIN PASSWORD $(escape_literal "$DB_PASSWORD");"
  echo "[+] Role $DB_USER already exists; password updated"
fi

db_exists=$("${PSQL_CMD[@]}" "${PSQL_ARGS[@]}" -tAc "SELECT 1 FROM pg_database WHERE datname = $(escape_literal "$DB_NAME")") || true
if [[ -z "$db_exists" ]]; then
  run_psql "CREATE DATABASE $(escape_identifier "$DB_NAME") OWNER $(escape_identifier "$DB_USER");"
  echo "[+] Created database $DB_NAME owned by $DB_USER"
else
  run_psql "ALTER DATABASE $(escape_identifier "$DB_NAME") OWNER TO $(escape_identifier "$DB_USER");"
  echo "[+] Database $DB_NAME already exists; ownership ensured"
fi

run_psql "GRANT ALL PRIVILEGES ON DATABASE $(escape_identifier "$DB_NAME") TO $(escape_identifier "$DB_USER");"

echo "[✓] Postgres role $DB_USER and database $DB_NAME are ready."

display_host="$DB_HOST"
if [[ "$display_host" == "/var/run/postgresql" ]]; then
  display_host="localhost"
fi
printf '    DATABASE_URL=postgres://%s:%s@%s:%s/%s\n' "$DB_USER" "$DB_PASSWORD" "$display_host" "$DB_PORT" "$DB_NAME"

if [[ -n "$SUPERUSER_PASSWORD" ]]; then
  unset PGPASSWORD
fi
