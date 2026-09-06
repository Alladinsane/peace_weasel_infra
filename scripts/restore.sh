#!/bin/sh
# Restores a specific backup into a specific environment.
# Required env: MYSQL_HOST, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE,
#   WP_CONTENT_PATH, OCI_BACKUP_BUCKET, OCI_BACKUP_PREFIX (dev|prod),
#   RESTORE_STAMP (e.g. 20260101-120000), VALIDATE_ONLY (optional: true)
set -eu
: "${MYSQL_HOST:?}" "${MYSQL_USER:?}" "${MYSQL_PASSWORD:?}" "${MYSQL_DATABASE:?}"
: "${WP_CONTENT_PATH:?}" "${OCI_BACKUP_BUCKET:?}" "${OCI_BACKUP_PREFIX:?}"
: "${RESTORE_STAMP:?Set RESTORE_STAMP=<timestamp> e.g. 20260101-120000}"

case "$OCI_BACKUP_PREFIX:$WP_CONTENT_PATH" in
  dev:/var/www/dev/wp-content|prod:/var/www/prod/wp-content) ;;
  *) echo "Refusing an unexpected restore prefix or WordPress path." >&2; exit 1 ;;
esac
printf '%s' "$RESTORE_STAMP" | grep -Eq '^[0-9]{8}-[0-9]{6}$' || {
  echo "RESTORE_STAMP must be YYYYMMDD-HHMMSS." >&2
  exit 1
}

PREFIX="$OCI_BACKUP_PREFIX/$RESTORE_STAMP"
WORK=/tmp/restore-$RESTORE_STAMP
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT

echo "Fetching $PREFIX from oci://$OCI_BACKUP_BUCKET ..."
oci os object get --bucket-name "$OCI_BACKUP_BUCKET" --name "$PREFIX/db.sql.gz" \
  --file "$WORK/db.sql.gz"
oci os object get --bucket-name "$OCI_BACKUP_BUCKET" --name "$PREFIX/wp-content.tar.gz" \
  --file "$WORK/wp-content.tar.gz"

test -s "$WORK/db.sql.gz" && test -s "$WORK/wp-content.tar.gz" || {
  echo "Backup is missing or empty." >&2
  exit 1
}
gzip -t "$WORK/db.sql.gz"
tar -tzf "$WORK/wp-content.tar.gz" >/dev/null
tar -tzf "$WORK/wp-content.tar.gz" | grep -qx 'wp-content/' || {
  echo "Backup does not contain a wp-content directory." >&2
  exit 1
}

if [ "${VALIDATE_ONLY:-false}" = "true" ]; then
  echo "Backup $PREFIX passed integrity validation."
  exit 0
fi

echo "Restoring $OCI_BACKUP_PREFIX database..."
gunzip -c "$WORK/db.sql.gz" > "$WORK/db.sql"
MYSQL_PWD="$MYSQL_PASSWORD" mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" "$MYSQL_DATABASE" < "$WORK/db.sql"

echo "Restoring wp-content..."
rm -rf "$WP_CONTENT_PATH"
tar -xzf "$WORK/wp-content.tar.gz" -C "$(dirname "$WP_CONTENT_PATH")"

echo "Restore of $PREFIX into $OCI_BACKUP_PREFIX complete."
