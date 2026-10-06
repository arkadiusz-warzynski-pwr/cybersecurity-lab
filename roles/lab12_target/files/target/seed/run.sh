#!/bin/sh
# Reporting helper, called by /etc/cron.d/report. Refreshes the timestamp the
# reporting dashboard reads; the reporting team extends it as needed.
echo "report generated at $(date -u +%Y-%m-%dT%H:%M:%SZ)" > /opt/report/last-run.txt
