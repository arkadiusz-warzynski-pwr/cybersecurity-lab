#!/usr/bin/env bash
# Export a sealed build VM as an OVA with a SHA256 checksum (macOS / Linux;
# on Windows use export.ps1). Sets the student defaults (RAM, CPUs, lab NAT
# Network) before exporting.
#   build/export.sh --vm kali-2026.2-arm64-build  --name "Kali Lab 2026-2027"   --version 2026.2  --out ~/cyberlab-ova
#   build/export.sh --vm ubuntu-26.04-arm64-build --name "Ubuntu Lab 2026-2027" --version 26.04.1 --out ~/cyberlab-ova
# Options: --arch amd64|arm64 (default: from the VM), --out DIR (default: build/out),
#          --memory MB (4096), --cpus N (2), --nat-network NAME ("Lab NAT Network")
# Works with the bash 3.2 that comes with macOS.
set -euo pipefail

die() { echo "Error: $*" >&2; exit 1; }

VM= NAME= VERSION= ARCH=
OUT="$(cd "$(dirname "$0")" && pwd)/out"
MEMORY=4096 CPUS=2 NATNET='Lab NAT Network'
ALLOW_SNAPSHOTS=0
while [ $# -gt 0 ]; do
    case $1 in
        --vm) VM=$2; shift 2 ;;               # build VM in VirtualBox
        --name) NAME=$2; shift 2 ;;           # VM name students see after import
        --version) VERSION=$2; shift 2 ;;
        --arch) ARCH=$2; shift 2 ;;
        --out) OUT=$2; shift 2 ;;
        --memory) MEMORY=$2; shift 2 ;;
        --cpus) CPUS=$2; shift 2 ;;
        --nat-network) NATNET=$2; shift 2 ;;
        --allow-snapshots) ALLOW_SNAPSHOTS=1; shift ;;   # export anyway (expect a much larger OVA)
        *) die "unknown option: $1" ;;
    esac
done
[ -n "$VM" ] && [ -n "$NAME" ] || die "usage: $0 --vm <build VM> --name <VM name> [--version V] [--out DIR]"

VBM=${VBOXMANAGE:-}
if [ -z "$VBM" ]; then
    if command -v VBoxManage >/dev/null 2>&1; then VBM=VBoxManage
    elif [ -x /Applications/VirtualBox.app/Contents/MacOS/VBoxManage ]; then VBM=/Applications/VirtualBox.app/Contents/MacOS/VBoxManage
    else die "VBoxManage not found"
    fi
fi
if command -v sha256sum >/dev/null 2>&1; then sha256() { sha256sum "$1" | cut -d' ' -f1; }
else sha256() { shasum -a 256 "$1" | cut -d' ' -f1; }
fi

info=$("$VBM" showvminfo "$VM" --machinereadable | tr -d '\r') || die "VM '$VM' not found"
vm_value() { printf '%s\n' "$info" | sed -n "s/^$1=\"\{0,1\}\([^\"]*\)\"\{0,1\}\$/\1/p" | head -n 1; }
state=$(vm_value VMState)
case $state in poweroff|aborted) ;; *) die "VM '$VM' must be powered off (state: $state)" ;; esac

# A VM with snapshots runs on a differencing disk, and the zero-fill in seal.yml
# cannot work there: VirtualBox does not store all-zero blocks, so those reads
# fall through to the parent, which still holds every file the seal deleted. The
# export merges the chain, ships that data and compresses badly - a ~7 GB OVA
# came out at ~25 GB. Seal and export a full clone instead:
#   VBoxManage clonevm <vm> --snapshot <snapshot> --mode machine --name <vm>-export --register
snaps=$(printf '%s\n' "$info" | grep -c '^SnapshotName' || true)
if [ "$snaps" -gt 0 ] && [ "$ALLOW_SNAPSHOTS" != 1 ]; then
    die "VM '$VM' has $snaps snapshot(s), so its disk is a differencing image and seal.yml's
zero-fill did not take effect. Full-clone it and export the clone (see the comment above this
check), or pass --allow-snapshots to export anyway."
fi

# Student defaults. The lab VMs share a VirtualBox NAT Network; students create it
# once (the download scripts do it), otherwise VirtualBox refuses to start the VM.
"$VBM" modifyvm "$VM" --memory "$MEMORY" --cpus "$CPUS" --nic1 natnetwork --nat-network1 "$NATNET" \
    --clipboard-mode bidirectional --drag-and-drop bidirectional || die "modifyvm failed"

if [ -z "$ARCH" ]; then
    if [ "$(vm_value platformArchitecture)" = ARM ]; then ARCH=arm64; else ARCH=amd64; fi
fi

# "Kali Lab 2026-2027" -> Kali-Lab-2026-2027-arm64.ova
base=$(printf '%s' "$NAME" | sed -E 's/[^A-Za-z0-9]+/-/g; s/^-+//; s/-+$//')
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
ova="$OUT/$base-$ARCH.ova"
[ ! -e "$ova" ] || die "$ova already exists"

# nomacs: every import gets new MAC addresses, so two copies (Ubuntu A and B)
# can share the NAT Network
set -- export "$VM" --output "$ova" --ovf20 --options manifest,nomacs \
    --vsys 0 --vmname "$NAME" --product Cybersecurity --description 'Login: stud / stud'
[ -z "$VERSION" ] || set -- "$@" --version "$VERSION"
"$VBM" "$@" || die "export failed"

hash=$(sha256 "$ova")
# LF line ending, so sha256sum -c / shasum -a 256 -c work
printf '%s  %s\n' "$hash" "$(basename "$ova")" > "$ova.sha256"
echo "$ova"
echo "SHA256 $hash"
