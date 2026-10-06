#!/usr/bin/env bash
# The Ubuntu half of the lab-fixes checks (labs 6-9). Same idea as
# verify-lab-env.sh, which covers the Kali VM: assert what docs/lab-fixes.md
# claims about the VM, so the instruction edits rest on something verified.
# Read-only; installs nothing and starts no services.
#
# What it cannot check: the actual VPN tunnel and the lab 8 MitM, which need
# Kali and a second Ubuntu running at the same time. Those stay open.
#
# Run inside the Ubuntu VM:
#   bash tests/verify-lab-env-ubuntu.sh
set -u
pass=0; fail=0; notes=0
ok()   { echo "  PASS  $1"; pass=$((pass+1)); }
no()   { echo "  FAIL  $1"; fail=$((fail+1)); }
note() { echo "  ..    $1"; notes=$((notes+1)); }

have() { command -v "$1" >/dev/null 2>&1; }

STUD_HOME=$(getent passwd stud 2>/dev/null | cut -d: -f6)
STUD_HOME=${STUD_HOME:-/home/stud}
# /home/stud is mode 700: running as the build user, a plain test -f reports
# "missing" for a file that is only unreadable, so these all go through sudo.
sf() { sudo test -f "$1"; }
sd() { sudo test -d "$1"; }

echo "== general =="
if [ "$STUD_HOME" = /home/stud ]; then
  ok "user stud, home /home/stud"
else
  no "course user is not stud with /home/stud (got '$STUD_HOME')"
fi
note "release: $(sed -n 's/^PRETTY_NAME=//p' /etc/os-release 2>/dev/null | tr -d '"')"
note "kernel: $(uname -r)  arch: $(dpkg --print-architecture)"
h=$(hostname)
case "$h" in
  ubuntu-a) ok "hostname ubuntu-a (this is client A, as distributed)" ;;
  ubuntu-b) note "hostname ubuntu-b - this VM has already been switched to client B" ;;
  *)        no "hostname is '$h', expected ubuntu-a (or ubuntu-b after lab-client B)" ;;
esac

echo "== lab 6 (hashes, Diffie-Hellman with Kali) =="
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

echo "== lab 7 (the students build the CA themselves) =="
CA="$STUD_HOME/openvpn-ca"
if sd "$CA"; then
  ok "EasyRSA folder at ~/openvpn-ca (not /home/server/EasyRSA-3.0.10)"
else
  no "~/openvpn-ca MISSING at $CA"
fi
if sf "$CA/vars.example"; then
  ok "vars.example present, for the students to copy"
else
  no "$CA/vars.example MISSING"
fi
# The point of the lab is that they build the PKI, so it must start empty.
if sd "$CA/pki"; then
  no "$CA/pki already exists - the CA must start unbuilt"
else
  ok "no pki/ yet, so the CA starts unbuilt as documented"
fi
if sf "$CA/vars"; then
  no "$CA/vars already exists - the students are told to create it"
else
  ok "no pre-made vars file, as documented"
fi
# lab-fixes: EasyRSA 3.2 only uses the organisation fields with
# `set_var EASYRSA_DN "org"`, which the students uncomment in vars.
if sudo grep -q 'EASYRSA_DN' "$CA/vars.example" 2>/dev/null; then
  ok "vars.example contains EASYRSA_DN (the line the lab text adds)"
else
  no "vars.example has no EASYRSA_DN - check the lab 7 instruction"
fi
if have easyrsa; then
  ok "easyrsa present ($(easyrsa --version 2>/dev/null | head -1 | awk '{ print $NF }'))"
else
  no "easyrsa MISSING"
fi
if have gpg; then
  ok "gpg present ($(gpg --version | head -1 | awk '{ print $NF }'))"
else
  no "gpg MISSING"
fi

echo "== lab 9 (VPN client) =="
if have openvpn; then
  ok "openvpn present ($(openvpn --version 2>/dev/null | head -1 | awk '{ print $2 }'))"
else
  no "openvpn MISSING"
fi
if [ -x /usr/local/bin/lab-client ]; then
  ok "lab-client command installed (turns a clone into client B)"
else
  no "/usr/local/bin/lab-client MISSING - the second lab 9 client cannot be made"
fi
# lab-client B reads the certificates from the shared store, not the Desktop.
if sd /usr/local/share/cyberlab/vpn/clientB; then
  ok "client B material staged in /usr/local/share/cyberlab/vpn"
else
  no "/usr/local/share/cyberlab/vpn/clientB MISSING - lab-client B would have nothing to install"
fi
case "$h" in
  ubuntu-b) THIS=clientB; OTHER=clientA ;;
  *)        THIS=clientA; OTHER=clientB ;;
esac
VPN="$STUD_HOME/Desktop/VPN/$THIS"
if sd "$VPN"; then
  ok "~/Desktop/VPN/$THIS present"
else
  no "$VPN MISSING"
fi
for f in ca.crt "$THIS.crt" "$THIS.key" "$THIS-tc2.key" client.ovpn; do
  if sf "$VPN/$f"; then ok "$THIS/$f present"; else no "$THIS/$f MISSING"; fi
done
# lab-fixes: step 4 (renaming the certificate in client.ovpn) and the
# "client others" folder are gone - each VM carries only its own client.
if sd "$STUD_HOME/Desktop/VPN/$OTHER"; then
  no "$OTHER folder is also present - the lab text says only this VM's client ships"
else
  ok "the other VM's client folder is absent, as documented"
fi
if sudo grep -q 'X\.X\.X\.X' "$VPN/client.ovpn" 2>/dev/null; then
  ok "client.ovpn still has the X.X.X.X placeholder the students replace with Kali's IP"
else
  note "client.ovpn has no X.X.X.X placeholder - check what the lab text tells them to edit"
  sudo sed -n 's/^remote /  remote line: /p' "$VPN/client.ovpn" 2>/dev/null | head -1
fi
if sudo grep -q '^tls-crypt-v2' "$VPN/client.ovpn" 2>/dev/null; then
  ok "client.ovpn uses tls-crypt-v2 (there is no ta.key any more)"
else
  no "client.ovpn has no tls-crypt-v2 line"
fi

echo "== lab 8 (MitM victim) =="
# The Ubuntu VM is the victim; the attack itself needs Kali on the same L2 and
# stays open in lab-fixes.md.
if have ip; then ok "ip present"; else no "iproute2 MISSING"; fi
note "the ARP/DNS-spoof run itself needs Kali and this VM up together - still open"

echo
echo "== $pass passed, $fail failed, $notes to read =="
[ "$fail" -eq 0 ]
