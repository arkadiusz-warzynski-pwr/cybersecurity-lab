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
| `build/export.ps1`, `build/export.sh` | OVA export on the host: Windows (PowerShell) / macOS and Linux (bash) |
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
| `ubuntu_tools` | Ubuntu | OpenSSL, GnuPG, EasyRSA, OpenVPN, netcat, SSH server, guest additions (amd64) |
| `vbox_additions` | both | arm64: guest additions from the VirtualBox Guest Additions ISO, if attached; display resize helper for Xfce (Kali) |
| `vpn_clients` | Ubuntu | both lab 9 clients in `/usr/local/share/cyberlab/vpn`, this VM's client in `~/Desktop/VPN`, the `lab-client A\|B` command |
| `easyrsa_lab7` | Ubuntu | empty EasyRSA folder `~/openvpn-ca` for lab 7 |
| `lab12_target` | Kali | lab 12 target image built into the VM (amd64 and arm64), the `lab12-target` start/stop/reset command |

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
4. On the host, export each VM (`export.ps1` on Windows, `export.sh` on macOS/Linux; same settings). The script sets 4 GB RAM, 2 CPUs and the Lab NAT Network, leaves out MAC addresses, exports to `build/out/` (or `-OutDir <folder>` to keep the OVAs outside the repository) and writes a SHA256 checksum:
   ```
   .\build\export.ps1 -VmName <kali build VM>   -Name "Kali Lab 2026-2027"   -Version 2026.2
   .\build\export.ps1 -VmName <ubuntu build VM> -Name "Ubuntu Lab 2026-2027" -Version 26.04.1
   ```

### Publishing a release
The student scripts (`scripts/get-vms.*`) download from the latest release and rely on its file names:
- `SHA256SUMS` lists every file: the OVAs and their parts.
- OVAs are named `<name>-<arch>.ova` (`amd64` / `arm64`, as the export scripts name them); the scripts take only those for the student's CPU. An OVA over 2 GB is split into `<ova>.part1`, `.part2`, …: `split -b 1900M --numeric-suffixes=1 -a 1 <ova> <ova>.part`.
- A VM whose name starts with `Ubuntu` is imported as `… A`, and with `CYBERLAB_WITH_B=1` also as `… B`.
- The VM name is read from the OVF descriptor (`<VirtualSystem ovf:id="…">`), which must be the first file in the OVA (VirtualBox exports it that way). The scripts fetch its first megabyte to skip OVAs whose VMs are already in VirtualBox.

arm64 OVAs can be added to the same release later; the scripts pick them up on Apple Silicon.

#### Refreshing a release within the same edition
When a VM is rebuilt mid-edition (for example Kali with the lab 12 target), the refreshed OVAs go
out as a **new release**, because the student scripts only ever read `releases/latest`. Three rules
follow from how those scripts work, and getting any of them wrong fails quietly:

1. **The rebuilt VM must get a new name.** The scripts skip a VM that is already in VirtualBox
   (`in_vbox`, matching the name from the OVF descriptor), so a refreshed OVA exported under the old
   name is silently never downloaded by anyone who already imported it — exactly the students who
   need it. Add a parenthesised note to the name, and the export scripts derive the file name from
   it:

   | | current | refreshed |
   |---|---|---|
   | VM name | `Kali Lab 2026-2027` | `Kali Lab 2026-2027 (lab12-updated)` |
   | OVA | `Kali-Lab-2026-2027-amd64.ova` | `Kali-Lab-2026-2027-lab12-updated-amd64.ova` |

   ```
   .\build\export.ps1 -VmName <kali build VM> -Name "Kali Lab 2026-2027 (lab12-updated)" -Version 2026.2
   ```

2. **VMs that did not change keep their name and are re-uploaded unchanged.** The release must
   contain *every* VM a new student needs, not just the rebuilt one: a student starting from scratch
   gets only what is in the latest release. Keeping the name also means students who already have
   that VM skip it (`'Ubuntu Lab 2026-2027' is already in VirtualBox`) and download only the rebuilt
   one. `SHA256SUMS` lists every file in the new release, re-uploaded ones included.

3. **Every architecture must be present, even one that was not rebuilt.** The scripts take only the
   files matching the student's CPU, so a release with no `-arm64` Kali leaves Apple Silicon students
   with no Kali at all. If only amd64 was rebuilt, re-upload the existing arm64 OVA **under its old
   name**: arm64 students then keep the VM they have (and skip the download), while the differing
   names make it visible that the two architectures are not at the same level. Say so in the release
   notes.

Release notes should also tell students to delete the superseded VM once the new one works —
otherwise both sit in VirtualBox, and the Kali VMs are about 26 GB each after import.

### Apple Silicon (arm64)
Step-by-step runbook: [macos-build.md](macos-build.md).

The playbooks choose the architecture themselves; all Kali and Ubuntu packages and the Juice Shop build exist for arm64 (checked 2026-09-29). Only the guest additions packages are amd64-only; on arm64 the `vbox_additions` role builds them from the Guest Additions ISO attached to the build VM (it does nothing without the ISO).
1. On the Mac: VirtualBox 7.2 for Apple Silicon, and the same NAT Network (`VBoxManage natnetwork add --netname "Lab NAT Network" --network 172.16.96.0/24 --enable --dhcp on`).
2. Quick test: install Kali (arm64 installer ISO) and Ubuntu 26.04.1 (arm64 desktop ISO), then run Option 2 from the README (`ansible-pull`) in both and go through lab 9.
3. OVAs: build as above. For Kali from the installer, create the build user `kali` during installation (or pass `-e build_user=<name>` to `seal.yml`). Export with `build/export.sh`; it names the files `…-arm64.ova` by itself:
   ```
   build/export.sh --vm <kali build VM> --name "Kali Lab 2026-2027" --version 2026.2 --out ~/ova
   ```

### Pitfalls from the 2026 build
- Take VirtualBox snapshots only with the VM powered off; live snapshots hung on the build host.
- On arm64, change a VM's DVD medium only with the VM powered off; changing it while running hung the guest's disk I/O.
- The Guest Additions from the ISO resize the display through VBoxDRMClient, which only sets the new preferred mode. GNOME switches to it, Xfce does not, so Kali gets `/usr/local/bin/vbox-autoresize` (Xfce autostart), which runs `xrandr --output <output> --auto` on every RandR output change.
- After `seal.yml` has started, new SSH connections fail (the host keys are deleted). Stream its log over a connection opened before.
- `seal.yml` must not delete anything the running playbook uses (`~/.ansible`, the repo copy, `/tmp`); that is done by the final `seal-finalize` script after the playbook ends.
- Zero-fill: `sync` before deleting the zero file, otherwise several GB of old data stay in free space and the OVA grows. Check an exported disk with `zerofree -n`.
- **Seal and export a VM that has no snapshots.** On a snapshot disk the zero-fill does nothing: the disk is a differencing image, VirtualBox does not store all-zero blocks, so those reads fall through to the parent, which still holds every file the seal deleted. The export merges the chain, ships that data and barely compresses — a 7 GB OVA came out at about 25 GB, with nothing reporting a problem. Full-clone the provisioned snapshot first and seal the clone: `VBoxManage clonevm <vm> --snapshot <snapshot> --mode machine --name <vm>-export --register`. The export scripts now refuse a VM with snapshots (`--allow-snapshots` / `-AllowSnapshots` overrides). Keep the snapshots on the original VM as the rollback.
- Never boot a VM with a copy of its own disk attached: identical file-system UUIDs can make it boot the copy. Attach copies after boot.
- **Two machines must not write to the same release at once.** On 2026-10-06 an amd64 upload from Windows and an arm64 upload from the Mac overlapped: the `SHA256SUMS` written 40 seconds after the other machine's last part listed stale hashes for the four assets it had just replaced, leaving `releases/latest` internally inconsistent while every file was present and looked fine. Whoever writes `SHA256SUMS` writes it last, once, knowing about both architectures. Note also that `gh release upload --clobber` deletes the existing asset *before* uploading the replacement, so the asset is missing for the whole transfer rather than merely changing at the end.
- Check uploaded assets without downloading them: `gh api repos/<owner>/<repo>/releases/tags/<tag> --jq '.assets[] | "\(.digest)  \(.name)"'` returns a sha256 per asset, which diffs straight against `SHA256SUMS`. That is how the mismatch above was caught.
- Changing the lab 12 target's files does **not** rebuild its image. The role builds only when `docker image inspect` fails, so a re-provision copies the new build context onto the VM and keeps the image that is already there — the change reaches the context and nothing else, with nothing reporting a problem. Delete the image first when `roles/lab12_target/files/target/` has changed: `sudo docker rmi -f cyberlab/lab12-target:2026`.
- Re-provisioning a VM that is more than a few days old: `base : Upgrade all packages` can upgrade `ansible-core` **underneath the running playbook**, and the next module call dies with `TypeError: run_module() missing 1 required keyword-only argument: 'secrets'`. Nothing is wrong with the playbook — run it again, the second run uses consistent code. Seen 2026-10-06 re-provisioning a sealed 2026-09-30 Kali (2.21.2 → 2.22.0~beta1; Kali rolling currently ships an ansible-core beta, which students get too via `ansible-pull`).

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
- [~] Lab 12 self-contained target (amd64 and arm64): built by the `lab12_target` role into Kali, replacing the Metasploitable download. amd64 built, sealed and exported 2026-10-05 as `Kali-Lab-2026-2027-lab12-updated-amd64.ova` (7.03 GiB, +3.6%); arm64 the same 2026-10-06 as `Kali-Lab-2026-2027-lab12-updated-arm64.ova` (6.21 GiB), `verify.sh` 11/11 and the exploitation chain validated live on aarch64. Published 2026-10-06 as release [`2026-2027-lab12-updated`](https://github.com/arkadiusz-warzynski-pwr/cybersecurity-lab/releases/tag/2026-2027-lab12-updated) (both Kali architectures rebuilt, both Ubuntus carried over unchanged, `SHA256SUMS` lists all 17 files); the student download test passed on Apple Silicon. Still to do: the docx. Design notes: the maintainer workspace, not this repository.
- [x] Lab 12 spoiler scrub (2026-10-06/07): the target's own files used to name the vectors, the CVEs and the task numbers in their comments, and three of them are installed inside the container as the very files the exercise is about, so the VM handed students the answer; `seal.yml` now also removes the build context. **Both architectures rebuilt from the scrubbed source** and uploaded to release `2026-2027-lab12-updated`, replacing the Kali assets in place under the same file names. amd64: image 307 MB, `verify.sh` 11/11, `verify-lab-env.sh` 38 passed / 1 failed (ZAP 2.17.0 against the documented 2.16), all three findings re-confirmed live, OVA 7.03 GiB at +3.4 MB over the previous build, post-seal check on the imported OVA passed. arm64: rebuilt and verified on the Mac the same night. Because both Kali OVAs kept their names, anyone who downloaded on 6 October has to delete `Kali Lab 2026-2027 (lab12-updated)` in VirtualBox before re-running the download script - `in_vbox()` skips a VM already registered under that name, so a same-named refresh is otherwise never fetched.
- [x] Test on arm64 (Mac): Kali 2026.2 and Ubuntu 26.04.1 built on Apple Silicon, lab 9 end to end (AES-256-GCM and DES-CBC/MD5), guest additions (clipboard, display resize), import test
- [x] arm64 OVAs added to release `2026-2027` (`SHA256SUMS` lists amd64 and arm64; release notes split by architecture)
- [x] Student download test on an Apple Silicon Mac (`get-vms.sh` from the README): only the arm64 files downloaded, both VMs imported, login screen and addresses on the Lab NAT Network
