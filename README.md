# Cyberbezpieczeństwo – course VMs

Ansible playbooks that turn a stock Kali Linux and a stock Ubuntu into the course VMs for labs 6–14. The same playbooks run on amd64 and arm64 (Apple Silicon).

| Playbook | VM | Used in |
|---|---|---|
| `kali.yml` | **Kali Lab 2026-2027** (Kali 2026.2) | labs 6–14 (attacker, VPN server) |
| `ubuntu.yml` | **Ubuntu Lab 2026-2027** (Ubuntu 26.04) | labs 6–9 (DH partner, lab 7 CA, lab 8 victim, lab 9 VPN clients A and B) |

Metasploitable 2 (labs 8, 10–12) is used as distributed.

## Two ways to get the VMs
**A. Ready-made OVAs (default).** Import the published `.ova` files into VirtualBox and log in as `stud` / `stud`. The Ubuntu VM starts as client A (hostname `ubuntu-a`). Lab 9 needs a second Ubuntu: clone the VM in VirtualBox (*Generate new MAC addresses for all network adapters*) or import the OVA a second time, then run `sudo lab-client B` in the copy. It becomes `ubuntu-b` with the client B VPN files, a new machine ID and new SSH host keys, and restarts.
All lab VMs are attached to the VirtualBox NAT Network **Lab NAT Network** (`172.16.96.0/24`). Create it once before starting the VMs, otherwise VirtualBox refuses to start them:
```
VBoxManage natnetwork add --netname "Lab NAT Network" --network 172.16.96.0/24 --enable --dhcp on
```
(or in VirtualBox: *File → Tools → Network Manager → NAT Networks → Create*, with the same name and prefix).

**C. Your own Kali / Ubuntu.** Run inside the VM:
```bash
sudo apt update && sudo apt install -y ansible-core git
sudo ansible-pull -U <repo-url> kali.yml -e course_user=$USER     # or ubuntu.yml
```
For a second Ubuntu, run `sudo lab-client B` in it after the playbook (or add `-e lab_client=B`). Add `-e full_upgrade=false` to skip the full system upgrade.

## Roles
| Role | VM | Purpose |
|---|---|---|
| `base` | both | apt upgrade, hostname, timezone, keyboard layout |
| `user` | both | course account (`stud`), groups |
| `services` | both | Kali: Apache and SSH, Ubuntu: SSH – enabled and running |
| `tools` | Kali | tools used in labs 6–14 |
| `juiceshop` | Kali | prebuilt Juice Shop in `~/Desktop/juice-shop` (labs 13–14) |
| `openvpn` | Kali | lab 9 VPN server in `/etc/openvpn/server` (not auto-started) |
| `ubuntu_tools` | Ubuntu | OpenSSL, GnuPG, EasyRSA, OpenVPN, netcat, SSH server, guest additions |
| `vpn_clients` | Ubuntu | both lab 9 clients in `/usr/local/share/cyberlab/vpn`, this VM's client in `~/Desktop/VPN`, and the `lab-client A\|B` command |
| `easyrsa_lab7` | Ubuntu | empty EasyRSA folder `~/openvpn-ca` for lab 7 |

Shared settings are in `group_vars/all.yml`, per-VM settings at the top of each playbook. Fixes needed in the lab PDFs are listed in `docs/lab-fixes.md`.

## Building the OVAs
1. Start from a fresh VM (Kali: official VirtualBox image; Ubuntu: fresh install) with a temporary build user that has SSH access and passwordless sudo (`/etc/sudoers.d/99-build`).
2. Copy the repo into the VM (only the files git tracks: `git ls-files -co --exclude-standard | tar cf repo.tar -T -`) and run the playbook: `ansible-playbook kali.yml` or `ansible-playbook ubuntu.yml`.
3. Run `ansible-playbook build/seal.yml`. It cleans the VM, removes the build access and powers off.
   - Kali: the build user `kali` is deleted.
   - Ubuntu (installed with the user `stud`): `ansible-playbook build/seal.yml -e build_user=stud -e remove_build_user=false` keeps `stud` and removes only its SSH keys and the temporary sudo rule.
4. On the host, export each VM. The script sets 4 GB RAM, 2 CPUs and the Lab NAT Network, leaves out MAC addresses, exports to `build/out/` and writes a SHA256 checksum:
   ```
   .\build\export.ps1 -VmName <kali build VM>   -Name "Kali Lab 2026-2027"   -Version 2026.2
   .\build\export.ps1 -VmName <ubuntu build VM> -Name "Ubuntu Lab 2026-2027" -Version 26.04.1
   ```

## VPN keys
Every VM gets the same lab 9 keys. `roles/openvpn/files/` holds the Kali server side and `roles/vpn_clients/files/` the Ubuntu clients (A and B). These keys are for the isolated lab network only and are public on purpose, since every student receives them in the VMs anyway; never use them for anything else. The CA private key is **not** in this repo; the instructor keeps it separately.

## Status
- [x] Kali 2026.2 (amd64): build, seal, export (import of a trial export tested)
- [x] Lab 9 end to end with Kali + Ubuntu A + Ubuntu B (all four cipher settings, A↔B netcat and file transfer)
- [x] Ubuntu 26.04 (amd64): single OVA with `lab-client`, build, clone test (`lab-client B`: new hostname, machine ID, host keys, IP; stays B on playbook re-run), seal, export
- [ ] Import test of the final OVAs (Ubuntu imported twice, one switched to B, on the Lab NAT Network)
- [ ] Test on arm64 (Mac)
