# Maintainer notes

How the course VMs are built, what is where, and what is still open. Student instructions are in the [README](../README.md); changes needed in the lab instructions are in [lab-fixes.md](lab-fixes.md).

## Repository layout
| Path | Purpose |
|---|---|
| `kali.yml` | Kali playbook (Kali Lab 2026-2027) |
| `ubuntu.yml` | Ubuntu playbook (Ubuntu Lab 2026-2027, client A by default) |
| `group_vars/all.yml` | shared settings: course user, password hash, timezone, keyboard, Juice Shop version |
| `roles/` | Ansible roles (below) |
| `build/seal.yml` | cleanup inside a build VM before export |
| `build/export.ps1` | OVA export on the Windows host |
| `build/out/` | exported OVAs (not in git) |
| `scripts/get-vms.ps1`, `scripts/get-vms.sh` | student download scripts (Windows / macOS + Linux): download, check, join, NAT Network, import Kali + Ubuntu A (Ubuntu B with `CYBERLAB_WITH_B=1`) |

## Roles
| Role | VM | Purpose |
|---|---|---|
| `base` | both | apt upgrade, hostname, timezone, keyboard layout |
| `user` | both | course account (`stud`), groups, GNOME keyboard layout |
| `services` | both | Kali: Apache and SSH, Ubuntu: SSH (socket) – enabled and running |
| `tools` | Kali | tools used in labs 6–14 |
| `juiceshop` | Kali | prebuilt Juice Shop in `~/Desktop/juice-shop` (labs 13–14) |
| `openvpn` | Kali | lab 9 VPN server in `/etc/openvpn/server` (not auto-started; IP forwarding on start) |
| `ubuntu_tools` | Ubuntu | OpenSSL, GnuPG, EasyRSA, OpenVPN, netcat, SSH server, guest additions |
| `vpn_clients` | Ubuntu | both lab 9 clients in `/usr/local/share/cyberlab/vpn`, this VM's client in `~/Desktop/VPN`, the `lab-client A\|B` command |
| `easyrsa_lab7` | Ubuntu | empty EasyRSA folder `~/openvpn-ca` for lab 7 |

Shared settings are in `group_vars/all.yml`, per-VM settings at the top of each playbook.

## Building the OVAs
1. Start from a fresh VM with a temporary build user that has SSH access and passwordless sudo (`/etc/sudoers.d/99-build`):
   - Kali: the official Kali VirtualBox image (user `kali`).
   - Ubuntu: a fresh install from the official desktop ISO with the user `stud` / `stud`.
2. Copy the repo into the VM, only the files git tracks (never `build/out`):
   `git ls-files -co --exclude-standard | tar cf repo.tar -T -`
   Then run `ansible-playbook kali.yml` or `ansible-playbook ubuntu.yml`.
3. Test, then run `ansible-playbook build/seal.yml`. It cleans the VM, zero-fills free space, removes the build access and powers off.
   - Kali: the build user `kali` is deleted.
   - Ubuntu: `ansible-playbook build/seal.yml -e build_user=stud -e remove_build_user=false` keeps `stud` and removes only its SSH keys and the temporary sudo rule.
4. On the host, export each VM. The script sets 4 GB RAM, 2 CPUs and the Lab NAT Network, leaves out MAC addresses, exports to `build/out/` (or `-OutDir <folder>` to keep the OVAs outside the repository) and writes a SHA256 checksum:
   ```
   .\build\export.ps1 -VmName <kali build VM>   -Name "Kali Lab 2026-2027"   -Version 2026.2
   .\build\export.ps1 -VmName <ubuntu build VM> -Name "Ubuntu Lab 2026-2027" -Version 26.04.1
   ```

### Publishing a release
The student scripts (`scripts/get-vms.*`) download from the latest release and rely on its file names:
- `SHA256SUMS` lists every file: the OVAs and their parts.
- OVAs are named `<name>-<arch>.ova` (`amd64` / `arm64`, as `export.ps1` names them); the scripts take only those for the student's CPU. An OVA over 2 GB is split into `<ova>.part1`, `.part2`, …: `split -b 1900M --numeric-suffixes=1 -a 1 <ova> <ova>.part`.
- A VM whose name starts with `Ubuntu` is imported as `… A`, and with `CYBERLAB_WITH_B=1` also as `… B`.
- The VM name is read from the OVF descriptor (`<VirtualSystem ovf:id="…">`), which must be the first file in the OVA (VirtualBox exports it that way). The scripts fetch its first megabyte to skip OVAs whose VMs are already in VirtualBox.

arm64 OVAs can be added to the same release later; the scripts pick them up on Apple Silicon.

### Apple Silicon (arm64)
The playbooks choose the architecture themselves; all Kali and Ubuntu packages and the Juice Shop build exist for arm64 (checked 2026-09-29). Only the Ubuntu guest additions package is amd64-only, so on arm64 it is skipped.
1. On the Mac: VirtualBox 7.2 for Apple Silicon, and the same NAT Network (`VBoxManage natnetwork add --netname "Lab NAT Network" --network 172.16.96.0/24 --enable --dhcp on`).
2. Quick test: install Kali (arm64 installer ISO) and Ubuntu 26.04.1 (arm64 desktop ISO), then run Option 2 from the README (`ansible-pull`) in both and go through lab 9.
3. OVAs: build as above. For Kali from the installer, create the build user `kali` during installation (or pass `-e build_user=<name>` to `seal.yml`). Export with PowerShell 7 (`brew install --cask powershell`); the script names the files `…-arm64.ova` by itself:
   ```
   pwsh ./build/export.ps1 -VmName <kali build VM> -Name "Kali Lab 2026-2027" -Version 2026.2 -OutDir ~/ova
   ```

### Pitfalls from the 2026 build
- Take VirtualBox snapshots only with the VM powered off; live snapshots hung on the build host.
- After `seal.yml` has started, new SSH connections fail (the host keys are deleted). Stream its log over a connection opened before.
- `seal.yml` must not delete anything the running playbook uses (`~/.ansible`, the repo copy, `/tmp`); that is done by the final `seal-finalize` script after the playbook ends.
- Zero-fill: `sync` before deleting the zero file, otherwise several GB of old data stay in free space and the OVA grows. Check an exported disk with `zerofree -n`.
- Never boot a VM with a copy of its own disk attached: identical file-system UUIDs can make it boot the copy. Attach copies after boot.

## VPN keys (lab 9)
Every VM gets the same keys: `roles/openvpn/files/` (Kali server) and `roles/vpn_clients/files/` (Ubuntu clients A and B). They are for the isolated lab network only and public on purpose, since every student receives them in the VMs anyway.

The CA private key is **not** in this repo; the instructor keeps it separately (EasyRSA PKI and the original `tc2-server.key`). To issue another client:
```bash
EASYRSA_PKI=$PWD/pki easyrsa build-client-full clientC nopass
openvpn --tls-crypt-v2 tc2-server.key --genkey tls-crypt-v2-client clientC-tc2.key
```
Certificates are valid until 2031 (CA until 2036).

## Status
- [x] Kali 2026.2 (amd64): build, seal, export
- [x] Lab 9 end to end with Kali + Ubuntu A + Ubuntu B (all four cipher settings, A↔B netcat and file transfer)
- [x] Ubuntu 26.04 (amd64): single OVA with `lab-client`, build, clone test (`lab-client B`: new hostname, machine ID, host keys, IP; stays B on playbook re-run), seal, export
- [x] Import test of the final OVAs: both boot to the login screen and get addresses on the Lab NAT Network
- [x] OVAs published as GitHub release [`2026-2027`](https://github.com/arkadiusz-warzynski-pwr/cybersecurity-lab/releases/tag/2026-2027) (split into parts under 2 GiB, `SHA256SUMS`; joining checked with `cat` and `copy /b`)
- [ ] Lab instruction updates (see [lab-fixes.md](lab-fixes.md))
- [ ] Test on arm64 (Mac)
