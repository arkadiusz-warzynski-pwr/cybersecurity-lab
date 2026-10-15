# Lab environment (2026-2027)

What the 2026-2027 lab VMs provide for each lab: accounts, network, locations and tool versions.
The lab instructions for this edition are written against this environment. Whatever a shell can
check is asserted by `tests/verify-lab-env.sh` inside the Kali VM and by
`tests/verify-lab-env-ubuntu.sh` inside the Ubuntu VM.

## General
- **Kali Lab 2026-2027 (lab12-updated)** – Kali 2026.2; **Ubuntu Lab 2026-2027** – Ubuntu 26.04.
  Both log in as `stud` / `stud` (home `/home/stud`); `stud` has `sudo`.
- Network: the VirtualBox NAT Network **Lab NAT Network**, `172.16.96.0/24`, with DHCP. The download
  scripts in the README create it and attach the VMs to it. To create it by hand:
  `VBoxManage natnetwork add --netname "Lab NAT Network" --network 172.16.96.0/24 --enable --dhcp on`.
- Both VMs reach the internet through the NAT Network.

## Metasploitable 2
Not distributed with the course VMs. Whether it is used in labs 8, 10 and 11 is the instructor's
decision; lab 12 does not use it. Where it is used, students download the official image
(<https://sourceforge.net/projects/metasploitable/>) and attach it to the Lab NAT Network.

| Lab | Metasploitable 2 |
|---|---|
| 8 | optional – Kali already runs a web server |
| 10, 11 | optional – any host on the Lab NAT Network can be the target |
| 12 | not used – the audited system is part of the Kali VM |

## Lab 6 – hash functions, Diffie-Hellman
- OpenSSL on both VMs.
- Files move between the VMs with `scp`: the SSH server is enabled on Kali and starts on demand on
  Ubuntu.
- CrypTool 1 is not part of the VMs; it is a Windows application students install on their own
  computer before the lab.

## Lab 7 – applied cryptography (Ubuntu)
- Easy-RSA 3.2 in `~/openvpn-ca`, with `vars.example` and no PKI yet.
- OpenVPN 2.7, GnuPG and OpenSSL.

## Lab 8 – attacks on communication
- Kali: Ettercap (graphical), Wireshark, and Apache enabled at boot. The Ettercap DNS file is
  `/etc/ettercap/etter.dns` (editing it needs `sudo`).
- The Ubuntu VM is on the same network.

## Lab 9 – communication protection
- Kali runs the OpenVPN server: configuration and keys in `/etc/openvpn/server/` (`server.conf`,
  `ca.crt`, `kali-vpn-server.crt`, `kali-vpn-server.key`, `tc2-server.key`), started with
  `sudo systemctl start openvpn-server@server`. The VPN network is `10.88.88.0/24`; traffic between
  clients is routed through the server.
- Two clients: Ubuntu A, and Ubuntu B added with the B option of the download script, then
  `sudo lab-client B` on it once. Client files are in `~/Desktop/VPN/clientA/` and
  `~/Desktop/VPN/clientB/` (`ca.crt`, client certificate and key, tls-crypt-v2 key, `client.ovpn`).
- The server accepts the data-channel ciphers AES-256-GCM, AES-128-CBC, DES-EDE-CBC and DES-CBC.

## Lab 10 – OSINT
- Kali: `whois`, `dig`, `host`, `dnsenum` (word list `/usr/share/dnsenum/dns.txt`), `fierce`,
  `dmitry`, `traceroute`, `tctrace` (irpas), `p0f`, `hping3`, `nbtscan` and `theHarvester` (the
  `duckduckgo` source works without an API key).

## Lab 11 – network reconnaissance
- Kali: `nmap`, Zenmap and `amap`. Scan types that build raw packets need `sudo`.

## Lab 12 – security audit and exploitation
- The audited system is part of the Kali VM and is controlled with `lab12-target`
  (`start`, `status`, `ip`, `stop`, `reset`). Everything else is in the lab instruction.

## Labs 13–14 – web application security
- OWASP Juice Shop 20.2.0 in `~/Desktop/juice-shop`: start it with `npm start` there and open
  `http://localhost:3000`.
- ZAP 2.17 and Firefox on Kali.

## Pending checks on the current build
These need a graphical session or a second machine, so they are checked by hand:

| Lab | Check |
|---|---|
| 6 | file exchange between Kali and Ubuntu |
| 7 | GnuPG steps on Ubuntu |
| 8 | the Ettercap exercise on the Lab NAT Network |
| 13 | Postman installation on Kali |
| 13–14 | ZAP 2.17 user interface |
| 14 | the cross-site exercise in Firefox |
