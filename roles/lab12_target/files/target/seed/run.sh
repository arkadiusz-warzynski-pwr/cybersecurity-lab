#!/bin/sh
# "Nightly reporting" helper, run as root by /etc/cron.d/report every minute.
# Intentionally benign: it just refreshes a report timestamp. The vulnerability
# is the file's permissions (root:report, group-writable), not this content.
echo "report generated at $(date -u +%Y-%m-%dT%H:%M:%SZ)" > /opt/report/last-run.txt
