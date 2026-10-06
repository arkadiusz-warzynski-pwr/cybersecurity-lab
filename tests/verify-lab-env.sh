#!/usr/bin/env bash
# Check the claims docs/lab-fixes.md makes about the Kali VM against the VM
# itself, so the instruction edits rest on something verified rather than
# remembered. Read-only: it installs nothing and starts no services.
#
# Only what a shell can see is checked here. GUI wording (ZAP and Ettercap menu
# names, the Juice Shop challenge UI) cannot be, so those items stay open in
# lab-fixes.md; what this script can do is report the versions behind them.
#
# Run inside the Kali VM:
#   bash tests/verify-lab-env.sh
set -u
pass=0; fail=0; notes=0
ok()   { echo "  PASS  $1"; pass=$((pass+1)); }
no()   { echo "  FAIL  $1"; fail=$((fail+1)); }
note() { echo "  ..    $1"; notes=$((notes+1)); }

have()    { command -v "$1" >/dev/null 2>&1; }
has_pkg() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"; }
tool()    { if have "$1"; then ok "$1 installed"; else no "$1 MISSING"; fi; }

STUD_HOME=$(getent passwd stud 2>/dev/null | cut -d: -f6)
STUD_HOME=${STUD_HOME:-/home/stud}

# Versions the lab instructions were written against. When the VM moves past
# one of these, the affected lab text needs another look - that is reported as
# a failure, because the docs and the VM then disagree.
DOC_JUICESHOP=20.2.0
DOC_ZAP=2.16

echo "== general =="
if [ "$STUD_HOME" = /home/stud ]; then
  ok "user stud, home /home/stud"
else
  no "course user is not stud with /home/stud (got '$STUD_HOME')"
fi
note "release: $(sed -n 's/^PRETTY_NAME=//p' /etc/os-release 2>/dev/null | tr -d '"')"
note "kernel: $(uname -r)  arch: $(dpkg --print-architecture)"

echo "== lab 6 (hashes, Diffie-Hellman) =="
if have openssl; then
  ok "openssl present ($(openssl version | awk '{ print $1, $2 }'))"
else
  no "openssl MISSING"
fi
if openssl pkeyutl -help >/dev/null 2>&1; then
  ok "openssl pkeyutl available (the lab text uses the lowercase binary)"
else
  no "openssl pkeyutl not available"
fi
if have CrypTool || have cryptool; then
  note "CrypTool found on the VM (lab-fixes says students install it themselves)"
else
  ok "CrypTool absent, as documented (students install it themselves)"
fi

echo "== lab 7 (GPG, OpenVPN key syntax) =="
if have gpg; then
  ok "gpg present ($(gpg --version | head -1 | awk '{ print $NF }'))"
else
  no "gpg MISSING"
fi
if have openvpn; then
  ok "openvpn present ($(openvpn --version 2>/dev/null | head -1 | awk '{ print $2 }'))"
else
  no "openvpn MISSING"
fi
# lab-fixes: `openvpn --genkey secret <file>` replaces the deprecated
# `--genkey --secret <file>`. Generated into a temp dir, then removed.
if have openvpn; then
  t=$(mktemp -d)
  if openvpn --genkey secret "$t/ta.key" >/dev/null 2>&1 && [ -s "$t/ta.key" ]; then
    ok "openvpn --genkey secret <file> works (the non-deprecated form)"
  else
    no "openvpn --genkey secret <file> failed"
  fi
  rm -rf "$t"
fi

echo "== lab 8 (MitM: ARP/DNS spoofing) =="
tool ettercap
have ettercap && note "ettercap: $(dpkg-query -W -f='${Version}' ettercap-common 2>/dev/null) (menu wording still needs a human)"
tool arpspoof
tool dnsspoof
if [ -f /etc/ettercap/etter.dns ]; then
  ok "/etc/ettercap/etter.dns present"
else
  no "/etc/ettercap/etter.dns MISSING"
fi
# lab-fixes: lab 8 needs no Metasploitable because Kali already serves HTTP -
# the services role enables apache2 for exactly this.
if systemctl is-enabled apache2 >/dev/null 2>&1; then
  ok "apache2 enabled (the lab 8 web server; no Metasploitable needed)"
else
  no "apache2 NOT enabled - lab 8 has no web server without Metasploitable"
fi

echo "== lab 9 (OpenVPN, tls-crypt-v2) =="
SRV=/etc/openvpn/server
for f in ca.crt kali-vpn-server.crt kali-vpn-server.key tc2-server.key server.conf; do
  if sudo test -f "$SRV/$f"; then ok "$SRV/$f present"; else no "$SRV/$f MISSING"; fi
done
if sudo test -f "$SRV/ta.key"; then
  no "$SRV/ta.key still present (lab-fixes says it is gone)"
else
  ok "no $SRV/ta.key, as documented"
fi
if sudo grep -q '^data-ciphers' "$SRV/server.conf" 2>/dev/null; then
  ok "server.conf sets data-ciphers ($(sudo sed -n 's/^data-ciphers *//p' "$SRV/server.conf" | head -1))"
else
  no "server.conf has no data-ciphers line (task 4.3 needs all four)"
fi
if systemctl list-unit-files 'openvpn-server@*' 2>/dev/null | grep -q openvpn-server; then
  ok "openvpn-server@.service exists (the lab text uses openvpn-server@server)"
else
  no "openvpn-server@.service MISSING"
fi

echo "== lab 10 (OSINT) =="
tool p0f
tool tctrace
tool nping
tool theHarvester
# lab-fixes: -b linkedin was removed upstream, so the docx now says duckduckgo.
if have theHarvester; then
  src=$(theHarvester -h 2>&1 | tr ',' '\n' | tr -d ' ')
  if echo "$src" | grep -qi duckduckgo; then
    ok "theHarvester still offers duckduckgo"
  else
    no "theHarvester no longer offers duckduckgo - the docx needs another source"
  fi
  if echo "$src" | grep -qi linkedin; then
    note "theHarvester lists linkedin again (the docx switched away from it)"
  else
    ok "theHarvester has no linkedin source, as documented"
  fi
fi

echo "== lab 11 (network reconnaissance) =="
tool nmap
tool amap
if have zenmap || has_pkg zenmap || has_pkg zenmap-kbx; then
  ok "zenmap installed"
else
  no "zenmap MISSING"
fi

echo "== lab 12 (vulnerability exploitation) =="
if [ -x /usr/local/bin/lab12-target ]; then
  ok "lab12-target helper installed"
else
  no "lab12-target helper MISSING"
fi
# Kali's sudo secure_path leaves out /usr/local/bin, hence the link.
if [ -e /usr/sbin/lab12-target ]; then
  ok "lab12-target reachable on sudo's secure_path (/usr/sbin link)"
else
  no "/usr/sbin/lab12-target link MISSING - sudo lab12-target would fail"
fi
if docker info >/dev/null 2>&1; then DK=docker; else DK="sudo docker"; fi
if $DK image inspect cyberlab/lab12-target:2026 >/dev/null 2>&1; then
  ok "target image present ($($DK images --format '{{ .Size }}' cyberlab/lab12-target:2026 | head -1))"
else
  no "target image cyberlab/lab12-target:2026 MISSING"
fi
# The target's source must not ship with the VM: it is the answer key.
if [ -e /usr/local/share/cyberlab/lab12 ]; then
  note "build context still present at /usr/local/share/cyberlab/lab12 (seal.yml removes it; expected before sealing)"
else
  ok "build context absent (students do not get the target's source)"
fi
note "the three findings themselves are covered by roles/lab12_target/tests/verify.sh"

echo "== labs 13-14 (Juice Shop, ZAP) =="
# /home/stud is mode 700, so these need sudo: run as the build user, a plain
# test -d reports "missing" for a directory that is simply unreadable.
JS="$STUD_HOME/Desktop/juice-shop"
if sudo test -d "$JS"; then
  ok "Juice Shop at ~/Desktop/juice-shop"
else
  no "Juice Shop MISSING at $JS"
fi
if sudo test -f "$JS/package.json"; then
  v=$(sudo sed -n 's/.*"version" *: *"\([^"]*\)".*/\1/p' "$JS/package.json" | head -1)
  if [ "$v" = "$DOC_JUICESHOP" ]; then
    ok "Juice Shop $v (the version labs 13/14 were checked against)"
  else
    no "Juice Shop is $v but the labs document $DOC_JUICESHOP - re-check labs 13/14"
  fi
fi
# lab-fixes: the 20.2.0 frontend bundle is main.js, not main-es2015.js.
bundle=$(sudo find "$JS/frontend/dist" -name 'main*.js' 2>/dev/null | head -3)
if [ -n "$bundle" ]; then
  if echo "$bundle" | grep -q 'main-es2015.js'; then
    note "a main-es2015.js bundle exists after all"
  else
    ok "the frontend bundle is main.js, as documented"
  fi
  note "bundle: $(echo "$bundle" | head -1)"
else
  note "frontend bundle not found (it is built on the first npm start)"
fi
if have zaproxy || has_pkg zaproxy; then
  ok "ZAP installed"
  zv=$(dpkg-query -W -f='${Version}' zaproxy 2>/dev/null)
  # The ZAP steps in labs 13/14 were written against 2.16, which had renamed its
  # proxy options. A different version is not a broken VM, but it does mean the
  # screenshots and menu paths need another look, so it is reported as a failure.
  case "$zv" in
    "$DOC_ZAP"*) ok "ZAP $zv matches the version labs 13/14 were written against" ;;
    *)           no "ZAP is $zv but labs 13/14 were written against $DOC_ZAP - re-check the ZAP steps" ;;
  esac
else
  no "ZAP MISSING"
fi
if have node; then
  ok "node present ($(node --version))"
else
  no "node MISSING"
fi
# Lab 13 step 12 has the students install snapd and Postman themselves
# ("sudo apt install snapd", then "snap install postman"), so snapd is not
# expected on the VM. Whether that sequence still works needs a real run.
if have snap || has_pkg snapd; then
  note "snapd already on the VM (lab 13 step 12 installs it itself)"
else
  ok "snapd absent, as expected (lab 13 step 12 installs it)"
fi

echo
echo "== $pass passed, $fail failed, $notes to read =="
[ "$fail" -eq 0 ]
