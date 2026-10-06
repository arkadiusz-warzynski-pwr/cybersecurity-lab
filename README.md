# Cybersecurity – lab VMs

Virtual machines for the Cybersecurity labs 6–14.

| VM | Used in |
|---|---|
| **Kali Lab 2026-2027 (lab12-updated)** – Kali 2026.2 | labs 6–14 |
| **Ubuntu Lab 2026-2027** – Ubuntu 26.04 | labs 6–9; lab 9 needs two copies (client A and B) |

Login on Kali and Ubuntu: **`stud` / `stud`**.

The Kali VM was rebuilt for lab 12, so in VirtualBox it appears as *Kali Lab 2026-2027 (lab12-updated)*. If you already imported an earlier *Kali Lab 2026-2027*, use the new one for labs 6–14; the old one can be removed (right-click it, *Remove*, then *Delete all files*) to free the disk space. The Ubuntu VM is unchanged.

## What you need
- VirtualBox 7.2 (or newer) on an Intel/AMD computer (amd64) or a Mac with Apple Silicon (arm64). Each VM exists in both versions; the download command picks the right one.
- About 50 GB of free disk space: Kali and Ubuntu take about 26 GB after import (33 GB with the second Ubuntu for lab 9) and grow as you use them; the downloaded `.ova` files (about 11 GB) can be deleted after import
- Each VM is set to 4 GB RAM. Lab 9 runs three VMs at once; if your computer has less memory, lower the RAM of the Ubuntu VMs in their settings.

## Option 1: ready-made VMs (recommended)
Install [VirtualBox 7.2 or newer](https://www.virtualbox.org/wiki/Downloads) first. Then run one command; do not download the `.ova` files in the browser. The command:
- downloads the VMs from the [latest release](https://github.com/arkadiusz-warzynski-pwr/cybersecurity-lab/releases/latest) (about 11 GB) into `Downloads/cyberlab-vms`
- checks them against `SHA256SUMS` and downloads damaged parts again
- creates the VirtualBox NAT Network **Lab NAT Network** (`172.16.96.0/24`), which all lab VMs use
- imports **Kali Lab 2026-2027 (lab12-updated)** and **Ubuntu Lab 2026-2027 A**

If it is interrupted (network, sleep, closed window), run the same command again: it continues where it stopped. VMs that are already in VirtualBox are not downloaded again.

**Windows:** open *PowerShell* (Start menu, type `powershell`; not as administrator) and paste:
```powershell
[Net.ServicePointManager]::SecurityProtocol = 'Tls12, Tls13'; irm https://raw.githubusercontent.com/arkadiusz-warzynski-pwr/cybersecurity-lab/master/scripts/get-vms.ps1 | iex
```

**macOS / Linux:** open *Terminal* and paste:
```bash
curl --tlsv1.2 -fsSL https://raw.githubusercontent.com/arkadiusz-warzynski-pwr/cybersecurity-lab/master/scripts/get-vms.sh | bash
```

**Before lab 9:** lab 9 needs a second Ubuntu (client B). Add it with the same command and one option; it downloads only the Ubuntu VM (about 4 GB) if it is no longer in the download folder:
- Windows (PowerShell):
  ```powershell
  $env:CYBERLAB_WITH_B = 1; [Net.ServicePointManager]::SecurityProtocol = 'Tls12, Tls13'; irm https://raw.githubusercontent.com/arkadiusz-warzynski-pwr/cybersecurity-lab/master/scripts/get-vms.ps1 | iex
  ```
- macOS / Linux:
  ```bash
  curl --tlsv1.2 -fsSL https://raw.githubusercontent.com/arkadiusz-warzynski-pwr/cybersecurity-lab/master/scripts/get-vms.sh | CYBERLAB_WITH_B=1 bash
  ```

Then start *Ubuntu Lab 2026-2027 B*, log in and run:
```bash
sudo lab-client B
```
It becomes `ubuntu-b` with the client B VPN files and restarts. *Ubuntu Lab 2026-2027 A* stays `ubuntu-a`.

<details>
<summary>Without the script (manual download)</summary>

1. **Create the lab network** (once); without it VirtualBox refuses to start the VMs:
   ```
   VBoxManage natnetwork add --netname "Lab NAT Network" --network 172.16.96.0/24 --enable --dhcp on
   ```
   Or in VirtualBox: *File → Tools → Network Manager → NAT Networks → Create*, with the same name and prefix.
2. **Download** from the [latest release](https://github.com/arkadiusz-warzynski-pwr/cybersecurity-lab/releases/latest) the `.part` files of your version (file names ending in `-amd64` for Intel/AMD, `-arm64` for Apple Silicon Macs) and `SHA256SUMS` into one folder. GitHub limits files to 2 GB, so each VM is split into parts. The names below are the ones in the current release; if a later release renames a VM, use the names listed in `SHA256SUMS`. **Join** them:
   - Windows (Command Prompt; in PowerShell put `cmd /c` in front):
     ```
     copy /b Kali-Lab-2026-2027-lab12-updated-amd64.ova.part1 + Kali-Lab-2026-2027-lab12-updated-amd64.ova.part2 + Kali-Lab-2026-2027-lab12-updated-amd64.ova.part3 + Kali-Lab-2026-2027-lab12-updated-amd64.ova.part4 Kali-Lab-2026-2027-lab12-updated-amd64.ova
     copy /b Ubuntu-Lab-2026-2027-amd64.ova.part1 + Ubuntu-Lab-2026-2027-amd64.ova.part2 Ubuntu-Lab-2026-2027-amd64.ova
     ```
   - Linux / Intel Mac:
     ```
     cat Kali-Lab-2026-2027-lab12-updated-amd64.ova.part* > Kali-Lab-2026-2027-lab12-updated-amd64.ova
     cat Ubuntu-Lab-2026-2027-amd64.ova.part* > Ubuntu-Lab-2026-2027-amd64.ova
     ```
   - Apple Silicon Mac:
     ```
     cat Kali-Lab-2026-2027-lab12-updated-arm64.ova.part* > Kali-Lab-2026-2027-lab12-updated-arm64.ova
     cat Ubuntu-Lab-2026-2027-arm64.ova.part* > Ubuntu-Lab-2026-2027-arm64.ova
     ```
   **Check** the files against `SHA256SUMS`: on Linux `sha256sum -c SHA256SUMS --ignore-missing`, on macOS `shasum -a 256 -c SHA256SUMS --ignore-missing`, on Windows (PowerShell) `Get-FileHash Kali-Lab-2026-2027-lab12-updated-amd64.ova` and compare with the value in `SHA256SUMS`. Every line must be `OK` or the hash must match; otherwise download the damaged part again. Afterwards the `.part` files can be deleted.
3. **Import** each file: *File → Import Appliance*.
4. **Second Ubuntu for lab 9:** clone the Ubuntu VM (*Clone → Generate new MAC addresses for all network adapters*) or import the Ubuntu OVA a second time, then run `sudo lab-client B` in the copy as above.

</details>

## Option 2: your own Kali / Ubuntu
If you already have Kali or Ubuntu, you can set it up with the same configuration. Run inside the VM:
```bash
sudo apt update && sudo apt install -y ansible-core git
sudo ansible-pull -U https://github.com/arkadiusz-warzynski-pwr/cybersecurity-lab.git kali.yml -e course_user=$USER     # or ubuntu.yml
```
For a second Ubuntu, run `sudo lab-client B` in it afterwards. Add `-e full_upgrade=false` to skip the full system upgrade.

On **Kali**, the run also builds the lab 12 target: it installs Docker, downloads the base images and compiles the target services inside them. Expect a long first run (well over the rest of the playbook on a laptop) and a working internet connection throughout; it uses about 1.8 GB of disk, of which roughly 1.5 GB is build cache that stays behind — `docker builder prune -af` reclaims it once the image is built, leaving about 300 MB. Later runs reuse the finished image and skip the build. In the ready-made VMs (option 1) the image is already built, so none of this happens there.

If the playbook stops with `TypeError: run_module() missing 1 required keyword-only argument: 'secrets'`, the full upgrade replaced `ansible-core` while it was running. Nothing is broken — run the same command again.

## Security note
The VMs use the password `stud` and run an SSH server. Keep them on the lab network; if you connect them to another network, change the password first (`passwd`). The VPN keys in the VMs and in this repository are for the lab only.

---
For instructors: how the VMs are built and maintained is in [docs/maintainer.md](docs/maintainer.md).
