#!/usr/bin/env bash
# Publish php-nginx-alpine images to GHCR from this machine.
# Usage: scripts/publish.sh [version]   (defaults to .php-version)
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"

VERSION="${1:-$(cat "$ROOT/.php-version")}"

echo "Logging in to ghcr.io (gh CLI token)"
GITHUB_USER="${GITHUB_USER:-$(gh api user --jq .login)}"
echo "$(gh auth token)" | docker login ghcr.io -u "$GITHUB_USER" --password-stdin >/dev/null

echo "Building + pushing runtime (local + cross via buildx)…"
docker buildx build \
    --platform linux/amd64,linux/arm64 --provenance=false \
    --build-arg PHP_VERSION="${VERSION}" \
    --target runtime \
    -t "ghcr.io/themusicdev/php-nginx-alpine:${VERSION}" \
    -t "ghcr.io/themusicdev/php-nginx-alpine:${VERSION%.*}" \
    --push \
    "$ROOT"

echo "Building + pushing dev…"
docker buildx build \
    --platform linux/amd64,linux/arm64 --provenance=false \
    --build-arg PHP_VERSION="${VERSION}" \
    --target dev \
    -t "ghcr.io/themusicdev/php-nginx-alpine:${VERSION}-dev" \
    -t "ghcr.io/themusicdev/php-nginx-alpine:${VERSION%.*}-dev" \
    --push \
    "$ROOT"

echo "Done:"
docker buildx imagetools inspect "ghcr.io/themusicdev/php-nginx-alpine:${VERSION}" | grep Platform
docker buildx imagetools inspect "ghcr.io/themusicdev/php-nginx-alpine:${VERSION}-dev" | grep Platform