#!/usr/bin/env bash
# Verify the Lab 12 target ENVIRONMENT is set up so the intended attack paths
# are possible (A vsftpd 2.3.4 reachable + non-root, B Log4Shell app up with the
# vulnerable flags, C writable root cron reachable from the foothold accounts).
# It does NOT run exploits — that is the instructor's to author/test.
#
# Run inside the Kali VM after the lab12_target role has been applied:
#   bash roles/lab12_target/tests/verify.sh
set -u
IP=10.12.0.10
pass=0; fail=0
ok()  { echo "  PASS  $1"; pass=$((pass+1)); }
no()  { echo "  FAIL  $1"; fail=$((fail+1)); }
# work whether or not the caller has docker group / is root
if docker info >/dev/null 2>&1; then DK="docker"; else DK="sudo docker"; fi
dex() { $DK exec lab12-target "$@" 2>/dev/null; }
HELPER=$(command -v lab12-target 2>/dev/null || echo /usr/local/bin/lab12-target)

# `reset`, not `start`: start() returns early when a container is already
# running, so a stale container from an earlier build would be verified instead
# of the current image — 11/11 against the wrong thing. reset always recreates.
echo "== resetting target (fresh container from the current image) =="
"$HELPER" reset >/dev/null 2>&1 || { echo "$HELPER reset failed"; exit 1; }
sleep 8

# Report what is actually under test, so a pass is self-evidencing.
img_tag=$($DK images --no-trunc --format '{{.ID}}' cyberlab/lab12-target:2026 2>/dev/null | head -1)
img_run=$($DK inspect -f '{{.Image}}' lab12-target 2>/dev/null)
echo "  image cyberlab/lab12-target:2026 = ${img_tag:-unknown}"
echo "  container is running             = ${img_run:-unknown}"
if [ -n "$img_tag" ] && [ -n "$img_run" ] && [ "$img_tag" != "$img_run" ]; then
  no "container is NOT running the current image (stale container)"
fi

echo "== A: vsftpd 2.3.4 (standalone; runs as root by design) =="
banner=$( (exec 3<>/dev/tcp/$IP/21; head -1 <&3) 2>/dev/null )
echo "$banner" | grep -q "2.3.4" && ok "vsftpd 2.3.4 banner on :21" || no "vsftpd 2.3.4 banner (got: $banner)"
dex sh -c 'command -v vsftpd >/dev/null || test -x /usr/local/sbin/vsftpd' && ok "vsftpd binary present" || no "vsftpd binary missing"

echo "== B: Log4Shell salary app, vulnerable flags, non-root =="
code=$(curl -s -o /dev/null -w '%{http_code}' "http://$IP:9876/" )
[ "$code" = 200 ] && ok "web app HTTP 200 on :9876" || no "web app HTTP (got $code)"
dex sh -c 'ps -o args= -C java' | grep -q "trustURLCodebase=true" && ok "app started with JNDI lookups enabled" || no "JNDI flag not on java cmdline"
juser=$(dex ps -o user= -C java | head -1 | tr -d ' ')
[ -n "$juser" ] && [ "$juser" != root ] && ok "salary app runs non-root (user $juser)" || no "salary app not non-root (user '$juser')"

echo "== C: writable root cron privesc =="
dex test -f /etc/cron.d/report && ok "root cron /etc/cron.d/report present" || no "cron job missing"
perms=$(dex stat -c '%U:%G %A' /opt/report/run.sh)
echo "$perms" | grep -q "root:report" && echo "$perms" | grep -q "rwxrwx" && ok "run.sh root:report, group-writable + executable ($perms)" || no "run.sh perms wrong ($perms)"
dex sh -c 'getent group report' | grep -qw "app" && ok "foothold account app in group report" || no "app not in group report"

echo "== escalation prerequisites =="
cred=$(dex stat -c '%U:%G %a' /etc/salary/db.conf)
echo "$cred" | grep -q "root:report 640" && ok "seeded cred /etc/salary/db.conf (root:report 640)" || no "cred file perms ($cred)"
dex sh -c 'command -v sshd >/dev/null' && ok "sshd installed (student enables it in task 3.5)" || no "sshd not installed"
# Distinguish "sshd not running" from "pgrep missing": a bare `pgrep` failure
# would otherwise be read as a pass (procps is installed explicitly for this).
if ! dex sh -c 'command -v pgrep >/dev/null'; then
  no "pgrep missing in the image - cannot check whether sshd is off"
elif dex pgrep -x sshd >/dev/null; then
  no "sshd already running (should be off)"
else
  ok "sshd not running yet (correct)"
fi

echo
echo "== $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
