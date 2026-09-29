# Cybersecurity – lab VMs

Virtual machines for the Cybersecurity labs 6–14.

| VM | Used in |
|---|---|
| **Kali Lab 2026-2027** (Kali 2026.2) | labs 6–14 |
| **Ubuntu Lab 2026-2027** (Ubuntu 26.04) | labs 6–9; lab 9 needs two copies (client A and B) |

Login on Kali and Ubuntu: **`stud` / `stud`**.

## What you need
- VirtualBox 7.2 (or newer) on an amd64 (Intel/AMD) computer
- About 50 GB of free disk space: the three VMs take about 33 GB after import and grow as you use them; the downloaded `.ova` files (about 11 GB) can be deleted after import
- Each VM is set to 4 GB RAM. Lab 9 runs three VMs at once; if your computer has less memory, lower the RAM of the Ubuntu VMs in their settings.

## Option 1: ready-made VMs (recommended)
Install VirtualBox first. Then run one command; do not download the `.ova` files in the browser. The command:
- downloads the VMs from the [latest release](https://github.com/arkadiusz-warzynski-pwr/cybersecurity-lab/releases/latest) (about 11 GB) into `Downloads/cyberlab-vms`
- checks them against `SHA256SUMS` and downloads damaged parts again
- creates the VirtualBox NAT Network **Lab NAT Network** (`172.16.96.0/24`), which all lab VMs use
- imports **Kali Lab 2026-2027**, **Ubuntu Lab 2026-2027 A** and **Ubuntu Lab 2026-2027 B** (the second Ubuntu is needed in lab 9)

If it is interrupted (network, sleep, closed window), run the same command again: it continues where it stopped.

**Windows:** open *PowerShell* (Start menu, type `powershell`; not as administrator) and paste:
```powershell
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; irm https://raw.githubusercontent.com/arkadiusz-warzynski-pwr/cybersecurity-lab/master/scripts/get-vms.ps1 | iex
```

**macOS / Linux:** open *Terminal* and paste:
```bash
curl -fsSL https://raw.githubusercontent.com/arkadiusz-warzynski-pwr/cybersecurity-lab/master/scripts/get-vms.sh | bash
```

**Before lab 9:** start *Ubuntu Lab 2026-2027 B* once, log in and run:
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
2. **Download** from the [latest release](https://github.com/arkadiusz-warzynski-pwr/cybersecurity-lab/releases/latest) all `.part` files and `SHA256SUMS` into one folder. GitHub limits files to 2 GB, so each VM is split into parts. **Join** them:
   - Windows (Command Prompt; in PowerShell put `cmd /c` in front):
     ```
     copy /b Kali-Lab-2026-2027-amd64.ova.part1 + Kali-Lab-2026-2027-amd64.ova.part2 + Kali-Lab-2026-2027-amd64.ova.part3 + Kali-Lab-2026-2027-amd64.ova.part4 Kali-Lab-2026-2027-amd64.ova
     copy /b Ubuntu-Lab-2026-2027-amd64.ova.part1 + Ubuntu-Lab-2026-2027-amd64.ova.part2 Ubuntu-Lab-2026-2027-amd64.ova
     ```
   - Linux / macOS:
     ```
     cat Kali-Lab-2026-2027-amd64.ova.part* > Kali-Lab-2026-2027-amd64.ova
     cat Ubuntu-Lab-2026-2027-amd64.ova.part* > Ubuntu-Lab-2026-2027-amd64.ova
     ```
   **Check** the files against `SHA256SUMS`: on Linux `sha256sum -c SHA256SUMS`, on macOS `shasum -a 256 -c SHA256SUMS`, on Windows (PowerShell) `Get-FileHash Kali-Lab-2026-2027-amd64.ova` and compare with the value in `SHA256SUMS`. Every line must be `OK` or the hash must match; otherwise download the damaged part again. Afterwards the `.part` files can be deleted.
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

## Security note
The VMs use the password `stud` and run an SSH server. Keep them on the lab network; if you connect them to another network, change the password first (`passwd`). The VPN keys in the VMs and in this repository are for the lab only.

---
For instructors: how the VMs are built and maintained is in [docs/maintainer.md](docs/maintainer.md).
