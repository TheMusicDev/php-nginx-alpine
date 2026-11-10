# Changelog

One line per published image tag.

## Unreleased

## 8.5.12-r2 — 2026-11-10

- Add PHP `redis` extension to the runtime and dev images
- Tag scheme: introduce image revisions (`8.5.12-r2`) — the revision tag is immutable; `8.5.12` and `8.5` now move on every publish; `.php-version` renamed to `.image-version` holding the full tag

## 8.5.12 — republished 2026-11-06

Same PHP version, new image digest — tooling/registry changes only, no runtime behavior change:

- `.php-version` is now the single source of truth for the PHP version; `scripts/publish.sh` and `tests/smoke-test.sh` read it and pass `--build-arg PHP_VERSION` explicitly (previously the build-arg wasn't passed at all, so the tag could say one version while the image actually contained the Dockerfile's hardcoded default).
- CI now also runs on push to `main` (was PR-only), so the build badge has a status to show.
- Now also published to Docker Hub (`docker.io/themusicdev/php-nginx-alpine`), alongside GHCR.

## 8.5.12 — 2026-11-04

- Initial release: generic nginx + PHP-FPM 8.5 Alpine runtime, GHCR-only.
