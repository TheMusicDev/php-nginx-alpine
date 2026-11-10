#!/usr/bin/env bash
# Publish php-nginx-alpine images to GHCR + Docker Hub from this machine.
# Usage: scripts/publish.sh [full-tags]   (defaults to .image-version, e.g. 8.5.12-r2)
#
# Tag scheme: `8.5.12-r2` is immutable (pin this), `8.5.12` moves to the
# latest revision of that patch, `8.5` moves to the latest patch.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"

FULLTAG="${1:-$(cat "$ROOT/.image-version")}"
PHP="${FULLTAG%%-*}"      # 8.5.12 -> the PHP_VERSION build arg
FLOAT="${PHP%.*}"         # 8.5    -> floating tag

echo "Logging in to ghcr.io (gh CLI token)"
GITHUB_USER="${GITHUB_USER:-$(gh api user --jq .login)}"
echo "$(gh auth token)" | docker login ghcr.io -u "$GITHUB_USER" --password-stdin >/dev/null

# Docker Hub: reuses whatever `docker login` session already exists on this
# machine (run `docker login` by hand first if that session has expired).

echo "Building + pushing runtime (local + cross via buildx)…"
docker buildx build \
    --platform linux/amd64,linux/arm64 --provenance=false \
    --build-arg PHP_VERSION="${PHP}" \
    --target runtime \
    -t "ghcr.io/themusicdev/php-nginx-alpine:${FULLTAG}" \
    -t "ghcr.io/themusicdev/php-nginx-alpine:${PHP}" \
    -t "ghcr.io/themusicdev/php-nginx-alpine:${FLOAT}" \
    -t "themusicdev/php-nginx-alpine:${FULLTAG}" \
    -t "themusicdev/php-nginx-alpine:${PHP}" \
    -t "themusicdev/php-nginx-alpine:${FLOAT}" \
    --push \
    "$ROOT"

echo "Building + pushing dev…"
docker buildx build \
    --platform linux/amd64,linux/arm64 --provenance=false \
    --build-arg PHP_VERSION="${PHP}" \
    --target dev \
    -t "ghcr.io/themusicdev/php-nginx-alpine:${FULLTAG}-dev" \
    -t "ghcr.io/themusicdev/php-nginx-alpine:${PHP}-dev" \
    -t "ghcr.io/themusicdev/php-nginx-alpine:${FLOAT}-dev" \
    -t "themusicdev/php-nginx-alpine:${FULLTAG}-dev" \
    -t "themusicdev/php-nginx-alpine:${PHP}-dev" \
    -t "themusicdev/php-nginx-alpine:${FLOAT}-dev" \
    --push \
    "$ROOT"

echo "Done:"
for tag in "ghcr.io/themusicdev/php-nginx-alpine:${FULLTAG}" "themusicdev/php-nginx-alpine:${FULLTAG}" \
           "ghcr.io/themusicdev/php-nginx-alpine:${FULLTAG}-dev" "themusicdev/php-nginx-alpine:${FULLTAG}-dev"; do
    docker buildx imagetools inspect "$tag" | grep Platform
done

# Cut CHANGELOG.md: turn "## Unreleased" notes into a dated release entry,
# leaving Unreleased empty for the next round of PRs. No-op if Unreleased
# has no bullets yet. Rewrites the file only — doesn't commit it.
CHANGELOG="$ROOT/CHANGELOG.md"
if [[ -f "$CHANGELOG" ]] && awk '/^## Unreleased/{f=1;next} /^## /{f=0} f && /^- /{found=1} END{exit !found}' "$CHANGELOG"; then
    DATE="$(date +%Y-%m-%d)"
    awk -v ver="$FULLTAG" -v date="$DATE" '
        { print }
        $0 == "## Unreleased" { print ""; print "## " ver " — " date }
    ' "$CHANGELOG" > "$CHANGELOG.tmp" && mv "$CHANGELOG.tmp" "$CHANGELOG"
    echo "CHANGELOG.md: cut \"${FULLTAG} — ${DATE}\" from Unreleased notes — review and commit it"
else
    echo "CHANGELOG.md: no Unreleased notes to cut, left as-is"
fi