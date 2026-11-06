# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Docker base image: nginx + PHP-FPM 8.5 on Alpine, single container (php-fpm over a unix socket + nginx, both supervised by supervisord). Not an app — a runtime that framework apps (CakePHP, Slim) build `FROM`. Two targets in one `Dockerfile`: `runtime` (prod) and `dev` (+ Xdebug, Node LTS, mariadb-client). No `latest` tag; registry is `ghcr.io/themusicdev/php-nginx-alpine` only.

## Commands

Build:
```sh
docker build --target runtime -t themusicdev/php-nginx-alpine:8.5.12 .
docker build --target dev -t themusicdev/php-nginx-alpine:8.5.12-dev .
```

Local smoke test (builds both targets, runs fixtures, asserts behavior):
```sh
tests/smoke-test.sh
```
This is the test suite — there is no separate unit-test runner. It builds both Docker targets, starts containers against `tests/fixtures/app-cake` and `tests/fixtures/app-slim`, and curls them to check: PHP version/extensions present (and `imagick`/`xdebug` absent in runtime), DOCROOT switching, nginx `try_files` rewrite, `X-Forwarded-For`/`X-Forwarded-Proto` handling, `tmp/`/`logs/` ownership, supervisord process state, HEALTHCHECK, and `server_tokens off`. To check a single thing manually, run the relevant `docker build`/`docker run` lines from the script by hand rather than editing the script.

Manual compose smoke run (CakePHP fixture + mariadb):
```sh
docker compose up -d
docker compose down
```

Publish to GHCR (local machine only — CI does not publish):
```sh
scripts/publish.sh 8.5.12
```
Requires `gh` auth and a Docker buildx builder with multi-platform (containerd) support — OrbStack provides this. Builds+pushes `runtime` as `:8.5.12`/`:8.5` and `dev` as `:8.5.12-dev`/`:8.5-dev` for `linux/amd64,linux/arm64`.

CI (`.github/workflows/build.yml`) builds and runs smoke tests on PRs; it does not publish.

## Architecture

- **One container, two processes.** `docker/supervisord.conf` runs `php-fpm` and `nginx` in the foreground, both logging to stdout/stderr. `docker/entrypoint.sh` is the `ENTRYPOINT`; it templates `$DOCROOT` into the nginx config, `mkdir`s the docroot/socket dir, and `chown`s `tmp/`/`logs/` for `www-data` before `exec`ing supervisord.
- **DOCROOT is the framework switch.** The base image sets `ENV DOCROOT=/var/www/html`; child Dockerfiles override it per framework (`/var/www/html/webroot` for CakePHP, `/var/www/html/public` for Slim). `entrypoint.sh` substitutes `__DOCROOT__` into `docker/nginx/default.conf` at container start — the nginx config is a template, not static. It also handles both app layouts when chowning `tmp`/`logs`: code root containing the docroot (CakePHP) vs. docroot itself (Slim).
- **No `.htaccess` support.** This is the main behavioral difference from the sibling `themusicdev/php-apache` image. Pretty URLs come from nginx `try_files $uri $uri/ /index.php?$query_string` in `docker/nginx/default.conf`. Any custom Apache rewrite/header rules from a child app must be translated into nginx and either override `docker/nginx/default.conf` entirely or get dropped as extra `*.conf` files into `/etc/nginx/http.d/` (loaded automatically at boot).
- **PHP reaches nginx only via unix socket** (`docker/php-fpm/zz-pool.conf`, socket at `/run/php-fpm-www.sock`), matching the `fastcgi_pass` in `default.conf`. There is no TCP path between nginx and php-fpm.
- **Proxy trust**: real client IP from `X-Forwarded-For` (private ranges trusted) and `HTTPS=on` surfaced to PHP when `X-Forwarded-Proto: https` — same contract as `themusicdev/php-apache`, so apps don't need to special-case this image. Verified by the proxy-header smoke tests.
- **Runtime vs. dev is a hard security boundary, not a convenience split.** `runtime` never installs Xdebug at all (zero risk of accidental enablement in prod); `dev` installs it but ships with `XDEBUG_MODE=off` by default via `docker/php/` config, overridable per-container with the `XDEBUG_MODE` env var. Never point a deploy at the `-dev` tag.
- **Version is a build arg, not hardcoded**: `ARG PHP_VERSION` (default `8.5.12`) selects the upstream `php:${PHP_VERSION}-fpm-alpine` base and is also baked into OCI labels. `scripts/publish.sh` and `tests/smoke-test.sh` both take/default this version independently — bumping the PHP patch version means passing it to both, not editing a shared constant.
- **Extension list is intentionally kept in parity with `themusicdev/php-apache`** (see README) — when adding/removing a PHP extension, check that sibling image's extension list too, and update the matching assertions in `tests/smoke-test.sh`.
