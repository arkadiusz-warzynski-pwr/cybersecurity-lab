#!/bin/sh
# Container entrypoint: render the salary service configuration, fix the
# application log ownership, then hand off to the process supervisor.
set -e

# The database password is injected at start time from the deployment template
# rather than stored in the image, so it differs per deployment.
TMPL=/usr/local/share/salary/db.conf.tmpl
CONF=/etc/salary/db.conf
if [ -f "$TMPL" ]; then
  secret=$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')
  [ -n "$secret" ] || { echo "entrypoint: could not generate the database password" >&2; exit 1; }
  sed "s/@@SECRET@@/${secret}/" "$TMPL" > "$CONF"
  chown root:report "$CONF"
  chmod 0640 "$CONF"
else
  echo "entrypoint: $TMPL missing - /etc/salary/db.conf not rendered" >&2
fi

touch /app/logs/app.log && chown app:app /app/logs/app.log
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/lab12.conf
