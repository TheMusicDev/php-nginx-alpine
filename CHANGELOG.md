# Changelog

One line per published image tag.

## Unreleased

- `.php-version` is now the single source of truth for the PHP version; `scripts/publish.sh` and `tests/smoke-test.sh` read it and pass `--build-arg PHP_VERSION` explicitly (previously the build-arg wasn't passed at all, so the tag could say one version while the image actually contained the Dockerfile's hardcoded default).
- CI now also runs on push to `main` (was PR-only), so the build badge has a status to show.

## 8.5.12 — 2026-11-04

- Initial release: generic nginx + PHP-FPM 8.5 Alpine runtime, GHCR-only.
