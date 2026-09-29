#!/usr/bin/env bash
# macOS / Linux: downloads the lab VMs from the latest release, checks them
# against SHA256SUMS, creates the Lab NAT Network and imports the VMs into
# VirtualBox. Run in a terminal:
#   curl -fsSL https://raw.githubusercontent.com/arkadiusz-warzynski-pwr/cybersecurity-lab/master/scripts/get-vms.sh | bash
# Safe to run again: finished steps are skipped, interrupted downloads resume.
# Optional environment variables (put them before "bash"):
#   CYBERLAB_DIR   download folder (default: ~/Downloads/cyberlab-vms)
#   CYBERLAB_TAG   release to use instead of the latest one
#   CYBERLAB_NO_B  set to 1 to import only one Ubuntu
# Works with the bash 3.2 that comes with macOS.
set -euo pipefail

# Everything is inside main, so bash reads the whole script before running
# it (with "curl | bash", commands that read stdin would eat the script).
main() {

REPO=arkadiusz-warzynski-pwr/cybersecurity-lab
NET_NAME='Lab NAT Network'
NET_PREFIX=172.16.96.0/24
PART_KB=$((1900 * 1024))   # parts are at most this big
DIR=${CYBERLAB_DIR:-$HOME/Downloads/cyberlab-vms}

say() { printf '\033[36m==> %s\033[0m\n' "$*"; }
die() { printf '\033[31mError: %s\033[0m\n' "$*" >&2; exit 1; }

# --- requirements -----------------------------------------------------------
VBM=${VBOXMANAGE:-}
if [ -z "$VBM" ]; then
    if command -v VBoxManage >/dev/null 2>&1; then VBM=VBoxManage
    elif [ -x /Applications/VirtualBox.app/Contents/MacOS/VBoxManage ]; then VBM=/Applications/VirtualBox.app/Contents/MacOS/VBoxManage
    else die "VirtualBox not found. Install VirtualBox 7.2 or newer first: https://www.virtualbox.org/wiki/Downloads"
    fi
fi
vbox_version=$("$VBM" --version | sed 's/[^0-9.].*//')
case $vbox_version in
    [0-6].*|7.[01]|7.[01].*) printf 'Warning: VirtualBox %s is older than 7.2; please update it.\n' "$vbox_version" >&2 ;;
esac
command -v curl >/dev/null 2>&1 || die "curl not found; install it first (e.g. sudo apt install curl)."

if command -v sha256sum >/dev/null 2>&1; then
    sha256() { sha256sum "$1" | cut -d' ' -f1; }
else
    sha256() { shasum -a 256 "$1" | cut -d' ' -f1; }
fi

case $(uname -m) in
    x86_64|amd64) ARCH=amd64 ;;
    arm64|aarch64) ARCH=arm64 ;;
    *) die "Unsupported CPU: $(uname -m)" ;;
esac

mkdir -p "$DIR"
cd "$DIR"

# --- release ----------------------------------------------------------------
if [ -n "${CYBERLAB_TAG:-}" ]; then TAG=$CYBERLAB_TAG; else
    latest=$(curl -sSI -o /dev/null -w '%{redirect_url}' "https://github.com/$REPO/releases/latest" || true)
    case $latest in
        */tag/*) TAG=${latest##*/tag/} ;;
        *) die "Could not find the latest release. Check your internet connection." ;;
    esac
fi
BASE=https://github.com/$REPO/releases/download/$TAG
say "Release $TAG, download folder $DIR"
curl -fsSL --retry 5 -o SHA256SUMS "$BASE/SHA256SUMS" || die "Could not download SHA256SUMS ($BASE/SHA256SUMS)"

expected() { awk -v n="$1" '{ f = $2; sub(/^\*/, "", f) } f == n { print $1; exit }' SHA256SUMS; }
names() { awk '{ f = $2; sub(/^\*/, "", f); print f }' SHA256SUMS; }
parts_of() {   # parts of an OVA in numeric order
    names | awk -v o="$1.part" 'index($0, o) == 1 { n = substr($0, length(o) + 1); if (n ~ /^[0-9]+$/) print n, $0 }' \
          | sort -n | cut -d' ' -f2
}
is_ok() { [ -f "$1" ] && [ "$(sha256 "$1")" = "$(expected "$1")" ]; }
size_kb() { if [ -f "$1" ]; then echo $(( $(wc -c < "$1") / 1024 )); else echo 0; fi; }

OVAS=$(names | grep -- "-$ARCH\.ova\$" | sort || true)
[ -n "$OVAS" ] || die "Release $TAG has no VMs for $ARCH computers. Use option 2 in the README (your own Kali / Ubuntu)."

# --- free space -------------------------------------------------------------
need=0; largest=0
for ova in $OVAS; do
    [ -f "$ova" ] && continue
    n=$(parts_of "$ova" | wc -l); [ "$n" -gt 0 ] || n=1
    n=$((n * PART_KB)); need=$((need + n)); [ "$n" -gt "$largest" ] && largest=$n
    for p in $(parts_of "$ova"); do need=$((need - $(size_kb "$p"))); done
done
need=$((need + largest))   # parts and the joined file exist at the same time
free=$(df -Pk . | awk 'NR == 2 { print $4 }')
if [ "$free" -lt "$need" ]; then
    die "Not enough free space in $DIR: about $((need / 1048576 + 1)) GB needed, $((free / 1048576)) GB free. Free some space or set CYBERLAB_DIR to a folder on another disk."
fi

# --- download, check, join --------------------------------------------------
get_checked() {
    if is_ok "$1"; then say "$1 already downloaded"; return; fi
    for try in 1 2; do
        say "Downloading $1"
        # a partial file from an interrupted run is resumed on the first try
        [ "$try" -gt 1 ] && rm -f "$1"
        curl -fL --retry 5 -C - --progress-bar -o "$1" "$BASE/$1" || true
        say "Checking $1"
        if is_ok "$1"; then return; fi
    done
    die "$1 is damaged after two downloads. Run the script again later."
}

for ova in $OVAS; do
    if [ -f "$ova" ] && [ ! -f "$ova.tmp" ]; then
        say "Checking $ova"
        if is_ok "$ova"; then continue; fi
        rm -f "$ova"
    fi
    parts=$(parts_of "$ova")
    if [ -z "$parts" ]; then get_checked "$ova"; continue; fi
    for p in $parts; do get_checked "$p"; done

    say "Joining $ova"
    # shellcheck disable=SC2086
    cat $parts > "$ova.tmp"
    mv -f "$ova.tmp" "$ova"
    say "Checking $ova"
    is_ok "$ova" || { rm -f "$ova"; die "$ova does not match SHA256SUMS. Run the script again."; }
    # shellcheck disable=SC2086
    rm -f $parts
done

# --- VirtualBox -------------------------------------------------------------
if ! "$VBM" natnetwork list | tr -d '\r' | grep -q "^Name: *$NET_NAME\$"; then
    say "Creating the VirtualBox NAT Network '$NET_NAME' ($NET_PREFIX)"
    "$VBM" natnetwork add --netname "$NET_NAME" --network "$NET_PREFIX" --enable --dhcp on \
        || die "Could not create the NAT Network."
fi

imported_b=0
for ova in $OVAS; do
    # VM name from the OVF descriptor, the first file in the OVA. (The name
    # "import -n" suggests gets " 1" appended when the VM already exists.)
    vm_name=$(head -c 1048576 "$ova" | LC_ALL=C tr -d '\000' | LC_ALL=C sed -n 's/.*<VirtualSystem ovf:id="\([^"]*\)".*/\1/p')
    if [ -z "$vm_name" ]; then
        vm_name=$("$VBM" import "$ova" -n | sed -n 's/.*Suggested VM name "\(.*\)".*/\1/p' | head -n 1)
    fi
    vms=$vm_name
    # lab 9 needs two Ubuntu VMs: client A and client B
    case $vm_name in
        Ubuntu*) vms="$vm_name A"; [ "${CYBERLAB_NO_B:-}" = 1 ] || vms="$vms
$vm_name B" ;;
    esac
    while IFS= read -r vm; do
        if "$VBM" list vms | grep -Fq "\"$vm\" "; then say "'$vm' is already in VirtualBox"; continue; fi
        say "Importing '$vm' (this takes a few minutes)"
        "$VBM" import "$ova" --vsys 0 --vmname "$vm" < /dev/null || die "Import of '$vm' failed. If VirtualBox now lists '$vm', remove it there (Remove > Delete all files) and run the script again."
        case $vm in *' B') imported_b=1 ;; esac
    done <<EOF
$vms
EOF
done

echo
say "Done. Log in on every VM as stud / stud."
if [ "$imported_b" = 1 ]; then
    echo "    Before lab 9: start the Ubuntu ... B VM once, log in and run:  sudo lab-client B"
fi
echo "    The .ova files in $DIR can be deleted now, or kept to reset a VM later."
}

main "$@"
