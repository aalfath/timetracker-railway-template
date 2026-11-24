#!/bin/bash
# Railway wrapper for TimeTracker. Runs as root, prepares the /data volume, then starts
# upstream's start.py (migrations + gunicorn) as the unprivileged "timetracker" user through
# /app/railway_bootstrap.py, which also sets the admin password from ADMIN_PASSWORD.
# Any failure exits non-zero so Railway's ON_FAILURE restart policy applies.
set -Eeuo pipefail

log() { echo "[railway-start] $*"; }

: "${DATABASE_URL:?DATABASE_URL is not set (it should reference the Postgres service)}"
: "${SECRET_KEY:?SECRET_KEY is not set}"
if [ "${#SECRET_KEY}" -lt 32 ]; then
  log "SECRET_KEY must be at least 32 characters"; exit 1
fi

# Public URL settings derived from Railway's domain unless the deployer set them.
if [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  export APP_BASE_URL="${APP_BASE_URL:-https://${RAILWAY_PUBLIC_DOMAIN}}"
  export WTF_CSRF_TRUSTED_ORIGINS="${WTF_CSRF_TRUSTED_ORIGINS:-https://${RAILWAY_PUBLIC_DOMAIN}}"
fi

DATA=/data
mkdir -p "$DATA/uploads" "$DATA/static-uploads" "$DATA/logs"

# Logos, editor and template images live under app/static/uploads upstream: keep them on the volume.
if [ ! -L /app/app/static/uploads ]; then
  cp -an /opt/static-uploads-seed/. "$DATA/static-uploads/"
  rm -r /app/app/static/uploads
  ln -s "$DATA/static-uploads" /app/app/static/uploads
fi

# Fernet key that encrypts stored secrets (SMTP, OAuth, integration tokens). Generated once,
# kept on the volume. A SETTINGS_ENCRYPTION_KEY variable, if set, takes precedence.
if [ -z "${SETTINGS_ENCRYPTION_KEY:-}" ] && [ ! -s "$DATA/settings.key" ]; then
  log "Generating settings encryption key in $DATA/settings.key"
  ( umask 077; python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())' > "$DATA/settings.key" )
fi

# Railway volumes are mounted root-owned: hand everything to the app user (only what isn't yet).
find "$DATA" ! -user timetracker -exec chown timetracker:timetracker {} +
[ -f "$DATA/settings.key" ] && chmod 600 "$DATA/settings.key"

cd /app
exec gosu timetracker python /app/railway_bootstrap.py
