#!/bin/sh
set -e

: "${DOCROOT:=/var/www/html}"
export DOCROOT

# Document root into the nginx server block (official-image sed pattern)
sed -ri -e "s!__DOCROOT__!${DOCROOT}!g" /etc/nginx/http.d/zz-default.conf

# socket dir; docs root may not exist on a blank container
mkdir -p /run/php-fpm "$DOCROOT"
chown nginx:nginx /var/cache/nginx 2>/dev/null || true

# App housekeeping: tmp/ and logs/ made www-data-writable when the app ships
# them, in either layout: code root containing the docroot (CakePHP) or the
# docroot itself (Slim)
APP_DIR="$(dirname "$DOCROOT")"
for base in "$APP_DIR" "$DOCROOT"; do
    for d in tmp logs; do
        [ -e "$base/$d" ] && chown -R www-data:www-data "$base/$d"
    done
done

exec supervisord -c /etc/supervisord.conf