# TimeTracker (DRYTRIX/TimeTracker) for Railway.
# Official image, pinned by version and digest. Bump both together and add a CHANGELOG.md entry.
FROM ghcr.io/drytrix/timetracker:5.21.0@sha256:2ed28cc6d555a6b713030ecb2508bd4658d9e2be6784e64dd04e723ebc6520fe

# The start script runs as root only to prepare the /data volume (Railway mounts it root-owned),
# then drops to the image's own "timetracker" user with gosu.
USER root

# Upstream bakes TZ=Europe/Rome into the image; default to UTC (override with a TZ variable).
ENV TZ=UTC \
    PORT=8080 \
    REDIS_ENABLED=false \
    PREFERRED_URL_SCHEME=https \
    INSTALLATION_CONFIG_DIR=/data \
    UPLOAD_FOLDER=/data/uploads \
    SETTINGS_ENCRYPTION_KEY_FILE=/data/settings.key \
    ALLOW_SELF_REGISTER=false

COPY --chmod=755 railway-start.sh /usr/local/bin/railway-start.sh
COPY --chmod=644 railway_bootstrap.py /app/railway_bootstrap.py

# Keep upstream's seed files (logo folder layout) so the start script can copy them onto the volume.
RUN cp -a /app/app/static/uploads /opt/static-uploads-seed

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/railway-start.sh"]
CMD []
