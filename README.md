# Cybersecurity – lab VMs 2026-2027

Virtual machines for the Cyberbezpieczeństwo labs 6–14.

| VM | Used in |
|---|---|
| **Kali Lab 2026-2027** (Kali 2026.2) | labs 6–14 |
| **Ubuntu Lab 2026-2027** (Ubuntu 26.04) | labs 6–9; lab 9 needs two copies (client A and B) |
| Metasploitable 2 | labs 8, 10–12 (from the course materials) |

Login on Kali and Ubuntu: **`stud` / `stud`**.

## What you need
- VirtualBox 7.2 (or newer) on an amd64 (Intel/AMD) computer
- About 50 GB of free disk space: the VMs take about 35 GB, the downloaded `.ova` files (about 10.5 GB) can be deleted after import
- Each VM is set to 4 GB RAM. Lab 9 runs three VMs at once; if your computer has less memory, lower the RAM of the Ubuntu VMs in their settings.

## Option 1: ready-made VMs (recommended)
1. **Create the lab network** (once). All lab VMs use the VirtualBox NAT Network **Lab NAT Network** (`172.16.96.0/24`); without it VirtualBox refuses to start them:
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
4. **Second Ubuntu for lab 9:** clone the Ubuntu VM (*Clone → Generate new MAC addresses for all network adapters*) or import the Ubuntu OVA a second time. Start the copy, log in and run:
   ```bash
   sudo lab-client B
   ```
   The copy becomes `ubuntu-b` with the client B VPN files and restarts. The original stays `ubuntu-a`.

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
