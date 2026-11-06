#!/usr/bin/env bash
# Publish php-nginx-alpine images to GHCR + Docker Hub from this machine.
# Usage: scripts/publish.sh [version]   (defaults to .php-version)
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"

VERSION="${1:-$(cat "$ROOT/.php-version")}"

echo "Logging in to ghcr.io (gh CLI token)"
GITHUB_USER="${GITHUB_USER:-$(gh api user --jq .login)}"
echo "$(gh auth token)" | docker login ghcr.io -u "$GITHUB_USER" --password-stdin >/dev/null

# Docker Hub: reuses whatever `docker login` session already exists on this
# machine (run `docker login` by hand first if that session has expired).

echo "Building + pushing runtime (local + cross via buildx)…"
docker buildx build \
    --platform linux/amd64,linux/arm64 --provenance=false \
    --build-arg PHP_VERSION="${VERSION}" \
    --target runtime \
    -t "ghcr.io/themusicdev/php-nginx-alpine:${VERSION}" \
    -t "ghcr.io/themusicdev/php-nginx-alpine:${VERSION%.*}" \
    -t "themusicdev/php-nginx-alpine:${VERSION}" \
    -t "themusicdev/php-nginx-alpine:${VERSION%.*}" \
    --push \
    "$ROOT"

echo "Building + pushing dev…"
docker buildx build \
    --platform linux/amd64,linux/arm64 --provenance=false \
    --build-arg PHP_VERSION="${VERSION}" \
    --target dev \
    -t "ghcr.io/themusicdev/php-nginx-alpine:${VERSION}-dev" \
    -t "ghcr.io/themusicdev/php-nginx-alpine:${VERSION%.*}-dev" \
    -t "themusicdev/php-nginx-alpine:${VERSION}-dev" \
    -t "themusicdev/php-nginx-alpine:${VERSION%.*}-dev" \
    --push \
    "$ROOT"

echo "Done:"
for tag in "ghcr.io/themusicdev/php-nginx-alpine:${VERSION}" "themusicdev/php-nginx-alpine:${VERSION}" \
           "ghcr.io/themusicdev/php-nginx-alpine:${VERSION}-dev" "themusicdev/php-nginx-alpine:${VERSION}-dev"; do
    docker buildx imagetools inspect "$tag" | grep Platform
done

# Cut CHANGELOG.md: turn "## Unreleased" notes into a dated release entry,
# leaving Unreleased empty for the next round of PRs. No-op if Unreleased
# has no bullets yet. Rewrites the file only — doesn't commit it.
CHANGELOG="$ROOT/CHANGELOG.md"
if [[ -f "$CHANGELOG" ]] && awk '/^## Unreleased/{f=1;next} /^## /{f=0} f && /^- /{found=1} END{exit !found}' "$CHANGELOG"; then
    DATE="$(date +%Y-%m-%d)"
    awk -v ver="$VERSION" -v date="$DATE" '
        { print }
        $0 == "## Unreleased" { print ""; print "## " ver " — " date }
    ' "$CHANGELOG" > "$CHANGELOG.tmp" && mv "$CHANGELOG.tmp" "$CHANGELOG"
    echo "CHANGELOG.md: cut \"${VERSION} — ${DATE}\" from Unreleased notes — review and commit it"
else
    echo "CHANGELOG.md: no Unreleased notes to cut, left as-is"
fi