#!/bin/sh
set -eu

: "${RUNNER_REPO:?Set RUNNER_REPO to owner/repository}"
: "${RUNNER_TOKEN:?Set RUNNER_TOKEN from GitHub's New self-hosted runner page}"

RUNNER_DIR=${RUNNER_DIR:-/opt/actions-runner}
RUNNER_LABEL=${RUNNER_LABEL:-peaceweasel}
RUNNER_VERSION=${RUNNER_VERSION:-2.329.0}

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this script as root." >&2
  exit 1
fi

install -d -o ubuntu -g ubuntu "$RUNNER_DIR"
if [ ! -x "$RUNNER_DIR/run.sh" ]; then
  archive="/tmp/actions-runner.tar.gz"
  curl -fsSL -o "$archive" "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-arm64-${RUNNER_VERSION}.tar.gz"
  tar -xzf "$archive" -C "$RUNNER_DIR"
  rm -f "$archive"
  chown -R ubuntu:ubuntu "$RUNNER_DIR"
fi

cd "$RUNNER_DIR"
if [ ! -f .runner ]; then
  su -s /bin/sh ubuntu -c "./config.sh --unattended --url https://github.com/$RUNNER_REPO --token $RUNNER_TOKEN --name $(hostname) --labels self-hosted,linux,ARM64,$RUNNER_LABEL --work _work --replace"
fi

./svc.sh install ubuntu
./svc.sh start
echo "Runner installed with label $RUNNER_LABEL."