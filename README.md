[![build](https://github.com/TheMusicDev/php-nginx-alpine/actions/workflows/build.yml/badge.svg)](https://github.com/TheMusicDev/php-nginx-alpine/actions/workflows/build.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

# themusicdev/php-nginx-alpine

Slim, framework-agnostic runtime: **nginx + PHP-FPM 8.5 on Alpine**, one container (php-fpm via unix socket + nginx, supervised). For resource-aware deployments, especially Dokploy projects (Traefik in front). Runtime only — apps come in with a tiny child Dockerfile.

Base: `php:8.5-fpm-alpine` (the patch tag is a build arg — `ARG PHP_VERSION`). Multi-arch: `linux/amd64`, `linux/arm64`. Image ~311MB vs ~1.0GB for themusicdev/php-apache.

## Tags

| Tag | Meaning |
|---|---|
| `8.5.12` / `8.5` | runtime |
| `8.5.12-dev` / `8.5-dev` | + Xdebug (off by default), Node LTS, mariadb-client, php.ini-development |

No `latest` tag. Published to both `ghcr.io/themusicdev/php-nginx-alpine` and `docker.io/themusicdev/php-nginx-alpine`.

`8.5` (and `8.5-dev`) are floating tags — they move to whatever patch was published last. Pin the full patch tag (`8.5.12`) in production child Dockerfiles; a floating tag can change under you on the next publish.

## Why two images, and Xdebug

Xdebug is a serious runtime cost **when active**: `debug`/`develop`/`profile` modes slow request handling multiples-over. With `XDEBUG_MODE=off` it costs much less, but the runtime image doesn't load it at all — zero risk of it being enabled by accident. Local debugging uses the `-dev` image (or `install-php-extensions xdebug` in your own dev child Dockerfile). Never deploy the dev image to prod.

## Env vars

| Var | Default | Notes |
|---|---|---|
| `DOCROOT` | `/var/www/html` | document root. CakePHP apps: `/var/www/html/webroot` (code mounted at `/var/www/html`); Slim apps: `/var/www/html/public` |

Build-time: extensions identical to themusicdev/php-apache: `intl pdo_mysql mysqli opcache zip gd (jpeg+webp+freetype) bcmath exif imagick soap xsl bz2 ftp pdo_pgsql pgsql gmp` + bundled `mbstring simplexml pdo_sqlite lexbor uri sodium`; Composer, git, unzip included.

## Child Dockerfile examples

CakePHP 5:

```dockerfile
FROM themusicdev/php-nginx-alpine:8.5.12
ENV DOCROOT=/var/www/html/webroot
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader --no-interaction
COPY . .
```

Slim:

```dockerfile
FROM themusicdev/php-nginx-alpine:8.5.12
ENV DOCROOT=/var/www/html/public
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader --no-interaction
COPY . .
```

## Different from themusicdev/php-apache

- nginx + php-fpm (unix socket) supervised in one container; Traefik hits port 80.
- **`.htaccess` is not honored.** Pretty URLs use `try_files $uri $uri/ /index.php?$query_string` (default CakePHP + Slim patterns). Custom Apache rewrite/header directives must be translated to an nginx server block (override `docker/nginx/default.conf` or mount your own).
- Same proxy behavior as the Apache image: real client IP from `X-Forwarded-For` (private ranges trusted), and PHP sees `HTTPS=on` when `X-Forwarded-Proto: https`.
- `gzip` compression + 7-day expires on static assets, `client_max_body_size 25m`, `server_tokens off`.
- php.ini: production + same `zz-app.ini` overrides.

Inside the container, add custom nginx config by dropping files in `/etc/nginx/http.d/` (`*.conf` are loaded at boot by the main `nginx.conf`).

## Publishing (manual, from this machine)

CI builds and runs the smoke tests on PRs; publishing is done locally (Docker multi-platform build, no QEMU wait):

```sh
scripts/publish.sh 8.5.12      # publishes 8.5.12, 8.5 (+ dev variants) to GHCR + Docker Hub
scripts/publish.sh              # defaults to the version in .php-version
```

Requires `gh` auth (uses `gh auth token` for the ghcr.io login), an existing `docker login` session for Docker Hub (run `docker login` by hand if it's expired — the script doesn't manage that credential), and Docker with containerd multi-platform support (OrbStack: yes).

`.php-version` at the repo root is the source of truth for the current PHP version — bump it when releasing, and `scripts/publish.sh`/`tests/smoke-test.sh` both read it (and pass it through as `--build-arg PHP_VERSION`, so the tag and what's actually baked into the image can't drift apart).

## Local testing

```sh
docker compose up -d
docker compose down
tests/smoke-test.sh
```