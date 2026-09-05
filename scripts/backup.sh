#!/bin/sh
# Dumps one environment's WP database + wp-content, pushes both to the
# shared Object Storage backups bucket under <prefix>/<timestamp>/.
# Env vars (set by backup.yml from that environment's own prod.env/dev.env):
#   MYSQL_HOST, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, WP_CONTENT_PATH,
#   OCI_BACKUP_BUCKET, OCI_BACKUP_PREFIX (dev|prod)
set -eu
: "${MYSQL_HOST:?}" "${MYSQL_USER:?}" "${MYSQL_PASSWORD:?}" "${MYSQL_DATABASE:?}"
: "${WP_CONTENT_PATH:?}" "${OCI_BACKUP_BUCKET:?}" "${OCI_BACKUP_PREFIX:?}"

STAMP=$(date +%Y%m%d-%H%M%S)
OUT_DIR=/tmp/backup-$STAMP
mkdir -p "$OUT_DIR"

echo "Dumping $OCI_BACKUP_PREFIX database..."
mysqldump -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
  | gzip > "$OUT_DIR/db.sql.gz"

echo "Archiving wp-content..."
tar -czf "$OUT_DIR/wp-content.tar.gz" -C "$(dirname "$WP_CONTENT_PATH")" "$(basename "$WP_CONTENT_PATH")"

PREFIX="$OCI_BACKUP_PREFIX/$STAMP"
echo "Uploading to oci://$OCI_BACKUP_BUCKET/$PREFIX/ ..."
oci os object put --bucket-name "$OCI_BACKUP_BUCKET" --file "$OUT_DIR/db.sql.gz" \
  --name "$PREFIX/db.sql.gz" --no-progress-bar
oci os object put --bucket-name "$OCI_BACKUP_BUCKET" --file "$OUT_DIR/wp-content.tar.gz" \
  --name "$PREFIX/wp-content.tar.gz" --no-progress-bar

rm -rf "$OUT_DIR"
echo "Backup $PREFIX complete."

# Retention: keep the last N backups PER ENVIRONMENT (prod kept longer than
# dev, since dev is disposable-by-design), to stay well inside the shared
# 10GB Always Free Standard allowance. Older ones fall through to the
# Terraform-managed lifecycle policy, which archives (doesn't delete) them.
if [ "$OCI_BACKUP_PREFIX" = "prod" ]; then KEEP=14; else KEEP=4; fi
oci os object list --bucket-name "$OCI_BACKUP_BUCKET" --prefix "$OCI_BACKUP_PREFIX/" \
  --query "data[].name" --raw-output \
  | tr -d '[]"' | tr ',' '\n' | cut -d/ -f1,2 | sort -u | sort -r | tail -n +"$((KEEP + 1))" \
  | while read -r old; do
      [ -n "$old" ] && oci os object bulk-delete --bucket-name "$OCI_BACKUP_BUCKET" --prefix "$old/" --force
    done
