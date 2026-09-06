#!/bin/sh
# Dumps one environment's WP database + wp-content, pushes both to the
# shared Object Storage backups bucket under <prefix>/<timestamp>/.
# Env vars (set by backup.yml from that environment's own prod.env/dev.env):
#   MYSQL_HOST, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, WP_CONTENT_PATH,
#   OCI_BACKUP_BUCKET, OCI_BACKUP_PREFIX (dev|prod)
set -eu
: "${MYSQL_HOST:?}" "${MYSQL_USER:?}" "${MYSQL_PASSWORD:?}" "${MYSQL_DATABASE:?}"
: "${WP_CONTENT_PATH:?}" "${OCI_BACKUP_BUCKET:?}" "${OCI_BACKUP_PREFIX:?}"

case "$OCI_BACKUP_PREFIX:$WP_CONTENT_PATH" in
  dev:/var/www/dev/wp-content|prod:/var/www/prod/wp-content) ;;
  *) echo "Refusing an unexpected backup prefix or WordPress path." >&2; exit 1 ;;
esac

STAMP=$(date +%Y%m%d-%H%M%S)
OUT_DIR=/tmp/backup-$STAMP
mkdir -p "$OUT_DIR"
trap 'rm -rf "$OUT_DIR"' EXIT

echo "Dumping $OCI_BACKUP_PREFIX database..."
MYSQL_PWD="$MYSQL_PASSWORD" mysqldump --single-transaction --quick \
  -h "$MYSQL_HOST" -u "$MYSQL_USER" "$MYSQL_DATABASE" > "$OUT_DIR/db.sql"
gzip -9 "$OUT_DIR/db.sql"
gzip -t "$OUT_DIR/db.sql.gz"

echo "Archiving wp-content..."
tar -czf "$OUT_DIR/wp-content.tar.gz" -C "$(dirname "$WP_CONTENT_PATH")" "$(basename "$WP_CONTENT_PATH")"
tar -tzf "$OUT_DIR/wp-content.tar.gz" >/dev/null

PREFIX="$OCI_BACKUP_PREFIX/$STAMP"
echo "Uploading to oci://$OCI_BACKUP_BUCKET/$PREFIX/ ..."
oci os object put --bucket-name "$OCI_BACKUP_BUCKET" --file "$OUT_DIR/db.sql.gz" \
  --name "$PREFIX/db.sql.gz" --no-progress-bar
oci os object put --bucket-name "$OCI_BACKUP_BUCKET" --file "$OUT_DIR/wp-content.tar.gz" \
  --name "$PREFIX/wp-content.tar.gz" --no-progress-bar
oci os object head --bucket-name "$OCI_BACKUP_BUCKET" --name "$PREFIX/db.sql.gz" >/dev/null
oci os object head --bucket-name "$OCI_BACKUP_BUCKET" --name "$PREFIX/wp-content.tar.gz" >/dev/null

echo "Backup $PREFIX complete."

# Retention is archive-only: OCI's lifecycle policy moves objects to the
# Archive tier after 45 days. Backups are never deleted automatically.
