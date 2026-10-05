#!/bin/sh
# Lab 12 target entrypoint: seed the task 3.3 credential, fix the app log
# ownership, then hand off to supervisor. The salary app (vector B) runs as
# non-root 'app'; cron (C) and vsftpd (A, standalone) run as root under
# supervisor.
set -e

# Task 3.3 credential, generated HERE rather than at image build time. A
# build-arg ends up in `docker history`, and 'stud' is in the docker group on the
# student VM, so it could be read off the image without touching the chain.
# Generating per start also gives every `lab12-target reset` a fresh value.
TMPL=/usr/local/share/salary/db.conf.tmpl
CONF=/etc/salary/db.conf
if [ -f "$TMPL" ]; then
  secret=$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')
  [ -n "$secret" ] || { echo "entrypoint: could not generate the seed credential" >&2; exit 1; }
  sed "s/@@SECRET@@/${secret}/" "$TMPL" > "$CONF"
  # root-owned, readable by group 'report' (the foothold account) - that
  # exposure is the finding; 0640 keeps it off-limits to everyone else.
  chown root:report "$CONF"
  chmod 0640 "$CONF"
else
  echo "entrypoint: $TMPL missing - /etc/salary/db.conf not seeded" >&2
fi

touch /app/logs/app.log && chown app:app /app/logs/app.log
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/lab12.conf
