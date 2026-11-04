#!/usr/bin/env bash
# Publish php-nginx-alpine images to GHCR from this machine.
# Usage: scripts/publish.sh 8.5.12
set -euo pipefail

VERSION="${1:?usage: scripts/publish.sh <version> (e.g. 8.5.12)}"

cd "$(dirname "$0")/.."
ROOT="$PWD"

echo "Logging in to ghcr.io (gh CLI token)"
echo "$(gh auth token)" | docker login ghcr.io -u "${GITHUB_USER:?set GITHUB_USER, e.g. angelxmoreno}" --password-stdin

echo "Building + pushing runtime (local + cross via buildx)…"
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --target runtime \
    -t "ghcr.io/themusicdev/php-nginx-alpine:${VERSION}" \
    -t "ghcr.io/themusicdev/php-nginx-alpine:${VERSION%.*}" \
    --push \
    "$ROOT"

echo "Building + pushing dev…"
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --target dev \
    -t "ghcr.io/themusicdev/php-nginx-alpine:${VERSION}-dev" \
    -t "ghcr.io/themusicdev/php-nginx-alpine:${VERSION%.*}-dev" \
    --push \
    "$ROOT"

echo "Done:"
docker buildx imagetools inspect "ghcr.io/themusicdev/php-nginx-alpine:${VERSION}" | grep Platform
docker buildx imagetools inspect "ghcr.io/themusicdev/php-nginx-alpine:${VERSION}-dev" | grep Platform