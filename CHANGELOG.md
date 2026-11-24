# Changelog

## 5.21.0 (2026-11-24)

- First release of the Railway template: TimeTracker `v5.21.0` (`ghcr.io/drytrix/timetracker:5.21.0`, pinned by digest) with Railway Postgres and a `/data` volume.
- The admin password comes from the generated `ADMIN_PASSWORD` variable on first boot, and the unauthenticated first-run wizard is marked complete, so a fresh deploy is never open to the first visitor.
