# Lab instruction fixes (2026)

Changes the lab PDFs need so they match the 2026 VMs (Kali 2026.2 and Ubuntu 26.04).
Items marked `[x]` are confirmed on the VMs; `[ ]` still need checking on the new build.

## General
- [x] The user on both Kali and Ubuntu is `stud` (home `/home/stud`). The PDFs also say `kali`, `student` and `server`.
- [x] The lab network is the VirtualBox NAT Network **Lab NAT Network**, `172.16.96.0/24`, as labs 9, 11 and 12 already say. The Kali OVA is attached to it. Add a setup step telling students to create it first (`VBoxManage natnetwork add --netname "Lab NAT Network" --network 172.16.96.0/24 --enable --dhcp on`); the Ubuntu VMs must use the same network. The download scripts from the README create it automatically.
- [x] Several commands contain en dashes (`–`) instead of `--`, which break when copied (lab 7 gpg commands, lab 12 `nmap –p1-65535 –A`).

## Lab 6
- [x] CrypTool 1 is not included in the VM.

## Lab 7 (Ubuntu, independent of lab 9)
- [x] The EasyRSA folder is `~/openvpn-ca`, not `/home/server/EasyRSA-3.0.10`. It starts empty: `vars.example` is present and there is no `pki/`, so students build the CA themselves.
- [x] Typo: `-signature encrypted_hash.sha25` → `encrypted_hash.sha256`.
- [ ] `openvpn --genkey --secret ta.key` is deprecated syntax. Use `openvpn --genkey secret ta.key`.

## Lab 9 (new VPN keys, tls-crypt-v2)
- [x] Kali server files in `/etc/openvpn/server/`: `ca.crt`, `kali-vpn-server.crt`, `kali-vpn-server.key`, `tc2-server.key`, `server.conf`. There is no `ta.key` any more.
- [x] Typo: `openvpn-server @ server.service` → `openvpn-server@server.service`.
- [ ] One Ubuntu VM is distributed (**Ubuntu Lab 2026-2027**, hostname `ubuntu-a`). New setup step for the second client: clone the Ubuntu VM in VirtualBox with *Generate new MAC addresses for all network adapters* (or import the OVA a second time), start the copy and run `sudo lab-client B`. The copy becomes `ubuntu-b`, gets its own machine ID and SSH host keys (so both can run on the NAT Network) and restarts. Client files: `~/Desktop/VPN/clientA/` on Ubuntu A and `~/Desktop/VPN/clientB/` on Ubuntu B, each holding `ca.crt`, `clientX.crt`, `clientX.key`, `clientX-tc2.key` and `client.ovpn`. Remove step 4 (renaming the certificate/key in `client.ovpn`) and the `client others` folder.
- [x] Start the client with `cd ~/Desktop/VPN/clientA && sudo openvpn --config client.ovpn`, after replacing `X.X.X.X` with Kali's IP.
- [x] Section IV says "Kali A / Kali B"; the clients are **Ubuntu A / Ubuntu B**.
- [x] Task 4.2: `/home/kali/Desktop/FILES/ubuntu.iso` doesn't exist. Create a test file instead: `head -c 900M /dev/urandom > ~/test.bin`.
- [x] Task 4.3: OpenVPN 2.7 negotiates the data-channel cipher, so `cipher` no longer selects it. For each setting, students edit `client.ovpn` on both clients: set `data-ciphers` to the single cipher (e.g. `data-ciphers DES-CBC`) and set `auth`. For the CBC settings (2–4) the **same `auth` must also be set in `/etc/openvpn/server/server.conf` on Kali**, followed by `sudo systemctl restart openvpn-server@server`; HMAC is not negotiated, and a mismatch lets the tunnel come up but every packet fails ("packet HMAC authentication failed"). The shipped server already accepts all four ciphers, and the legacy provider needed for DES is enabled on both sides. All four settings were tested between Kali 2026.2 and Ubuntu 26.04. The `auth` value is ignored for AES-256-GCM (setting 1), and OpenVPN warns that DES ciphers are insecure and will be removed in OpenVPN 2.8.
- [x] Section IV (netcat between Ubuntu A and B through the VPN): the server routes client-to-client traffic through the kernel, so Kali enables IP forwarding (and disables ICMP redirects, which otherwise show up as ping errors) when the VPN server starts. Tested with Ubuntu A (10.88.88.2) and B (10.88.88.3): ping 0% loss, `nc -l -p 7777` on B and `nc 10.88.88.3 7777` on A work as written, and the traffic is visible on Kali's `tun0` (each packet twice: in and out). A 50 MB file took about 6 s (AES-256-GCM), so the 900 MB transfer in task 4.2 takes about 1.5 minutes per setting.
- [ ] Wireshark filter: `ssl.record.version == 0x0303` → `tls.record.version == 0x0303`.

## Lab 10
- [x] `p0f` and `tctrace` (irpas) are now installed.
- [ ] `theHarvester -b linkedin`: check which sources the current version supports.

## Lab 11
- [x] `amap` and Zenmap are installed.

## Labs 13-14 (Juice Shop 20.2.0)
- [x] Juice Shop is in `~/Desktop/juice-shop`; start it with `npm start` and open `localhost:3000`.
- [ ] Walk through every step against 20.2.0. The labs were written for an older version. `main-es2015.js` is probably `main.js` now, and ZAP 2.16 renamed its proxy options.
- [ ] Lab 13 step XII (snapd + Postman on Kali): check it still works.
- [ ] Lab 14 CSRF: check `htmledit.squarefree.com` still exists and the attack works with current Firefox cookie defaults.
