# Building the arm64 OVAs on a Mac (Apple Silicon)

Goal: **Kali Lab 2026-2027** and **Ubuntu Lab 2026-2027** for Apple Silicon, added to the existing GitHub release [`2026-2027`](https://github.com/arkadiusz-warzynski-pwr/cybersecurity-lab/releases/tag/2026-2027) next to the amd64 files. Same configuration as amd64: user `stud` / `stud`, 4 GB RAM, 2 CPUs, Lab NAT Network. General build notes and pitfalls: [maintainer.md](maintainer.md).

The playbooks choose the architecture themselves (`deb_arch` in `group_vars/all.yml`): all packages and the Juice Shop build exist for arm64; the Ubuntu guest additions package is amd64-only and is skipped. `build/export.ps1` names the files `…-arm64.ova` by itself, and the student scripts pick arm64 files on Apple Silicon.

## 0. Prerequisites on the Mac
- VirtualBox 7.2 or newer, the **macOS / Apple Silicon** build. Check: `VBoxManage --version`.
- Homebrew, then: `brew install --cask powershell` (for `export.ps1`), `brew install coreutils gh` (`gsplit` for the release parts, GitHub CLI).
- About 100 GB free disk space (two build VMs, a clone for the lab 9 test, OVAs, parts).
- The repository: `git clone https://github.com/arkadiusz-warzynski-pwr/cybersecurity-lab.git`. Set the repo-local git identity before committing.
- The lab network, once: `VBoxManage natnetwork add --netname "Lab NAT Network" --network 172.16.96.0/24 --enable --dhcp on`

## 1. Installation images
Download and check against the published SHA256SUMS:

| VM | Image | Checksums |
|---|---|---|
| Kali | https://cdimage.kali.org/kali-2026.2/kali-linux-2026.2-installer-arm64.iso | https://cdimage.kali.org/kali-2026.2/SHA256SUMS |
| Ubuntu | https://cdimage.ubuntu.com/releases/26.04.1/release/ubuntu-26.04.1-desktop-arm64.iso | https://cdimage.ubuntu.com/releases/26.04.1/release/SHA256SUMS |

`shasum -a 256 <iso>` and compare with the line in SHA256SUMS.

## 2. Build VMs (VirtualBox GUI, "New")
Create each VM with the wizard (it sets the correct ARM defaults: EFI, storage controller, graphics), skip unattended installation:

| | Kali | Ubuntu |
|---|---|---|
| Name | `kali-2026.2-arm64-build` | `ubuntu-26.04-arm64-build` |
| ISO | Kali arm64 installer | Ubuntu 26.04.1 desktop arm64 |
| RAM / CPUs | 4096 MB / 2 | 4096 MB / 2 |
| Disk | 80 GB, dynamically allocated | 30 GB, dynamically allocated |
| Network (for the build) | Bridged Adapter (Wi-Fi/Ethernet), so the Mac can reach it by SSH | same |

`export.ps1` switches the adapter to the Lab NAT Network at export time.

### Installing the systems
- **Kali:** graphical install, default Xfce desktop and tool selection. Create the user **`kali`** (it is the temporary build user; `build/seal.yml` deletes it). Partitioning: guided, entire disk, **all files in one partition** (a single ext4 root keeps the zero-fill simple).
- **Ubuntu:** default installation. User **`stud`**, password **`stud`**, computer name `ubuntu`.

### Build access
On the Mac, create a key for the build (once): `ssh-keygen -t ed25519 -f ~/.ssh/cyberlab_build -N ""`

In each VM's console, logged in as the build user (`kali` on Kali, `stud` on Ubuntu):
```bash
sudo apt-get update && sudo apt-get install -y openssh-server   # Ubuntu desktop has no SSH server by default
sudo systemctl enable --now ssh
echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/99-build
ip -4 addr show   # note the bridged IP address
```
On the Mac: `ssh-copy-id -i ~/.ssh/cyberlab_build.pub <user>@<vm-ip>` (asks for the VM password once), then check `ssh -i ~/.ssh/cyberlab_build <user>@<vm-ip> sudo -n true`.

Shut the VMs down and take snapshots **with the VM powered off**: `before-provision` (Kali), `clean-install` (Ubuntu).

## 3. Provisioning
From the repository folder on the Mac (`K=~/.ssh/cyberlab_build`, `H=<user>@<vm-ip>`). Copy only the files git tracks, without macOS metadata (`._*` files, extended attributes):
```bash
git ls-files -co --exclude-standard | COPYFILE_DISABLE=1 tar --no-mac-metadata -cf - -T - \
  | ssh -i $K $H 'mkdir -p ~/cybersecurity-lab && tar xf - -C ~/cybersecurity-lab'
ssh -i $K $H 'sudo apt-get update -qq && sudo apt-get install -y ansible-core'
ssh -i $K $H 'cd ~/cybersecurity-lab && setsid nohup ansible-playbook kali.yml > ~/provision.log 2>&1 < /dev/null &'   # ubuntu.yml on Ubuntu
```
The run includes a full upgrade and takes a while. Follow it with `ssh -i $K $H 'tail -n 5 ~/provision.log'`; it is done when `PLAY RECAP` shows `failed=0`. Do not use `pgrep`/`pkill` with a pattern that also appears in the same SSH command line (it matches itself).

## 4. Tests before sealing
- Both: re-run the playbook once; it should finish with `failed=0` and few changes.
- **Kali:** Juice Shop (arm64 build) starts: `sudo -u stud bash -lc 'cd ~/Desktop/juice-shop && timeout 90 npm start' &` then `curl -s -o /dev/null -w '%{http_code}' localhost:3000` returns `200`. Spot-check a few tools (`nmap`, `zaproxy`, `amap`, `p0f`, `tctrace`, `wireshark`).
- **Lab 9 end to end** (see the Lab 9 items in [lab-fixes.md](lab-fixes.md)):
  1. Take a snapshot of the Ubuntu build VM (powered off), then clone it: `VBoxManage clonevm ubuntu-26.04-arm64-build --name ubuntu-arm64-B --register` (new MAC addresses by default). Start the clone and run `sudo lab-client B` in it.
  2. On Kali: `sudo systemctl start openvpn-server@server`; on both Ubuntus replace `X.X.X.X` in `~/Desktop/VPN/client{A,B}/client.ovpn` with Kali's IP and start `sudo openvpn --config client.ovpn` in that folder.
  3. Ping between the clients' `tun0` addresses (10.88.88.x), `nc -l -p 7777` on one and `nc <vpn-ip> 7777` on the other, and one DES setting (`data-ciphers DES-CBC`, `auth MD5` on both clients **and** in `/etc/openvpn/server/server.conf`, then restart the server).
  4. Afterwards delete the clone and restore the Ubuntu snapshot, so the lab 9 edits do not end up in the OVA.

## 5. Sealing
Open the SSH connection first and keep it; `seal.yml` deletes the host keys, so new connections fail afterwards. About 20 seconds after it ends, the build access is removed and the VM powers off.
```bash
ssh -i $K $H 'cd ~/cybersecurity-lab && ansible-playbook build/seal.yml 2>&1 | tee ~/seal.log'                                              # Kali
ssh -i $K $H 'cd ~/cybersecurity-lab && ansible-playbook build/seal.yml -e build_user=stud -e remove_build_user=false 2>&1 | tee ~/seal.log'  # Ubuntu
```
When the VM is off, take a snapshot `sealed-<date>`.

## 6. Export
```bash
pwsh ./build/export.ps1 -VmName kali-2026.2-arm64-build  -Name "Kali Lab 2026-2027"   -Version 2026.2  -OutDir ~/cyberlab-ova
pwsh ./build/export.ps1 -VmName ubuntu-26.04-arm64-build -Name "Ubuntu Lab 2026-2027" -Version 26.04.1 -OutDir ~/cyberlab-ova
```
Result: `Kali-Lab-2026-2027-arm64.ova`, `Ubuntu-Lab-2026-2027-arm64.ova` and a `.sha256` file for each. The sizes should be close to the amd64 ones (Kali about 7 GB, Ubuntu about 4 GB); a much larger file means the zero-fill did not work.

Import test: import both OVAs under other names, start them, check that they reach the login screen and get an address on the Lab NAT Network, then delete the test VMs.

## 7. Adding the files to the release
The student scripts find the VMs through `SHA256SUMS`, so it must list the arm64 files as well as the existing amd64 ones. Upload the parts first and `SHA256SUMS` last.
```bash
cd ~/cyberlab-ova
for f in Kali-Lab-2026-2027-arm64.ova Ubuntu-Lab-2026-2027-arm64.ova; do
  gsplit -b 1900M --numeric-suffixes=1 -a 1 "$f" "$f.part"     # macOS split has no --numeric-suffixes
done
R=arkadiusz-warzynski-pwr/cybersecurity-lab
gh release download 2026-2027 -R $R -p SHA256SUMS --clobber
shasum -a 256 *-arm64.ova *-arm64.ova.part* >> SHA256SUMS
sort -k2 -u SHA256SUMS -o SHA256SUMS; cat SHA256SUMS            # amd64 and arm64 lines, no duplicates
shasum -a 256 -c SHA256SUMS --ignore-missing                     # arm64 lines must be OK
gh release upload 2026-2027 -R $R *-arm64.ova.part*
gh release upload 2026-2027 -R $R SHA256SUMS --clobber
```
Check the uploaded assets (`gh release view 2026-2027 -R $R --json assets`), then test as a student on the Mac with the macOS command from the README: it must download the arm64 files and import Kali and Ubuntu A.

## 8. Documentation
- `README.md`, "What you need": Apple Silicon Macs are supported (the scripts choose the right files).
- Release notes: add the arm64 rows to the table (file names and sizes).
- `docs/maintainer.md`, Status: tick "Test on arm64 (Mac)".
