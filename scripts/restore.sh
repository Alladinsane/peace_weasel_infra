#!/bin/sh
# Restores a specific backup into a specific environment.
# Required env: MYSQL_HOST, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE,
#   WP_CONTENT_PATH, OCI_BACKUP_BUCKET, OCI_BACKUP_PREFIX (dev|prod),
#   RESTORE_STAMP (e.g. 20260101-120000)
set -eu
: "${MYSQL_HOST:?}" "${MYSQL_USER:?}" "${MYSQL_PASSWORD:?}" "${MYSQL_DATABASE:?}"
: "${WP_CONTENT_PATH:?}" "${OCI_BACKUP_BUCKET:?}" "${OCI_BACKUP_PREFIX:?}"
: "${RESTORE_STAMP:?Set RESTORE_STAMP=<timestamp> e.g. 20260101-120000}"

PREFIX="$OCI_BACKUP_PREFIX/$RESTORE_STAMP"
WORK=/tmp/restore-$RESTORE_STAMP
mkdir -p "$WORK"

echo "Fetching $PREFIX from oci://$OCI_BACKUP_BUCKET ..."
oci os object get --bucket-name "$OCI_BACKUP_BUCKET" --name "$PREFIX/db.sql.gz" \
  --file "$WORK/db.sql.gz"
oci os object get --bucket-name "$OCI_BACKUP_BUCKET" --name "$PREFIX/wp-content.tar.gz" \
  --file "$WORK/wp-content.tar.gz"

echo "Restoring $OCI_BACKUP_PREFIX database..."
gunzip -c "$WORK/db.sql.gz" | mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"

echo "Restoring wp-content..."
rm -rf "$WP_CONTENT_PATH"
tar -xzf "$WORK/wp-content.tar.gz" -C "$(dirname "$WP_CONTENT_PATH")"

rm -rf "$WORK"
echo "Restore of $PREFIX into $OCI_BACKUP_PREFIX complete."
