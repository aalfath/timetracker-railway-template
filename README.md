[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/timetracker?utm_medium=integration&utm_source=button&utm_campaign=timetracker)

# TimeTracker on Railway

One-click Railway template for [TimeTracker](https://github.com/DRYTRIX/TimeTracker) (`DRYTRIX/TimeTracker`, GPL-3.0): self-hosted time tracking, projects, clients and PDF invoices for freelancers and teams.

**Version:** TimeTracker `v5.21.0`, official image `ghcr.io/drytrix/timetracker:5.21.0@sha256:2ed28cc6d555a6b713030ecb2508bd4658d9e2be6784e64dd04e723ebc6520fe`.

## What it deploys

| Service | Source | What it does |
|---|---|---|
| **TimeTracker** | this repo (`Dockerfile`) | Flask web app on `PORT` 8080, public domain, health check `/_ready`, volume at `/data` (settings, uploads, logos, encryption key) |
| **Postgres** | Railway PostgreSQL | All app data, on its own volume |

Redis, nginx/certgen, Ollama, the Peppol bridge and the Prometheus/Grafana stack from upstream's compose file are left out: Railway terminates TLS, and the rest is optional upstream.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | Private-network connection to Postgres |
| `SECRET_KEY` | `${{secret(64,"abcdef0123456789")}}` | Flask session/CSRF key |
| `ADMIN_USERNAMES` | `admin` | Admin login name(s), comma-separated |
| `ADMIN_PASSWORD` | `${{secret(24)}}` | Initial admin password, set on first boot. Read it in the service's **Variables** tab |
| `METRICS_TOKEN` | `${{secret(32)}}` | Bearer token for `/metrics` (otherwise public) |
| `PORT` | `8080` | Port the app listens on |

Nothing to fill in. The start script also sets `APP_BASE_URL` and `WTF_CSRF_TRUSTED_ORIGINS` from the Railway domain, `TZ=UTC`, `REDIS_ENABLED=false`, and generates a Fernet key for stored secrets in `/data/settings.key`. If you add a custom domain, set `APP_BASE_URL` and `WTF_CSRF_TRUSTED_ORIGINS` to `https://YOUR-DOMAIN`.

## First login

1. Open the public URL and log in as `admin` with the `ADMIN_PASSWORD` value.
2. Change the password under your profile. The wrapper only sets a password for an admin that has none, so your change survives redeploys.
3. Set company details, timezone and currency in **Admin → Settings** (the open first-run wizard is skipped so no stranger can configure your instance before you).

## Wrapper

- `railway-start.sh` (root): checks the required variables, moves `app/static/uploads` onto the volume, generates the settings key, fixes volume ownership, then drops to the image's `timetracker` user.
- `railway_bootstrap.py`: runs upstream's `start.py` (DB wait, Alembic migrations under a Postgres advisory lock, gunicorn) and sets the admin password from `ADMIN_PASSWORD` before the server starts. Any failure exits non-zero, so Railway restarts the service.

## Resources

Tested on 0.5 GB RAM / 1 vCPU (Railway Free plan limits): idle about 230 MB, about 310 MB peak after creating a client, project, time entry and invoice PDF. The template uses two volumes (Postgres and `/data`); Railway's Free plan allows one volume per project, so use the Trial, Hobby or a higher plan.

## Updates

Railway notifies deployers when this repo's `main` changes. Each bump changes the pinned version and digest in the `Dockerfile` and adds an entry to `CHANGELOG.md` (breaking changes first). Migrations run on start. Back up Postgres before applying an update.

## Telemetry

Upstream's image sends an anonymous install heartbeat (install ID, version, OS, no user data) to the TimeTracker project's Grafana Cloud endpoint. Detailed analytics stay off unless an admin opts in.
