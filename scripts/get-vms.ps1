# Windows: downloads the lab VMs from the latest release, checks them against
# SHA256SUMS, creates the Lab NAT Network and imports the VMs into VirtualBox.
# Run in PowerShell (not as administrator):
#   [Net.ServicePointManager]::SecurityProtocol = 'Tls12'; irm https://raw.githubusercontent.com/arkadiusz-warzynski-pwr/cybersecurity-lab/master/scripts/get-vms.ps1 | iex
# Safe to run again: finished steps are skipped, interrupted downloads resume.
# Optional environment variables:
#   CYBERLAB_DIR   download folder (default: Downloads\cyberlab-vms)
#   CYBERLAB_TAG   release to use instead of the latest one
#   CYBERLAB_NO_B  set to 1 to import only one Ubuntu
& {
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$repo = 'arkadiusz-warzynski-pwr/cybersecurity-lab'
$netName = 'Lab NAT Network'
$netPrefix = '172.16.96.0/24'
$partSize = 1900MB   # parts are at most this big
$dir = if ($env:CYBERLAB_DIR) { $env:CYBERLAB_DIR } else { Join-Path $HOME 'Downloads\cyberlab-vms' }

function Say($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Get-Sha256($file) { (Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash.ToLower() }

# --- requirements -----------------------------------------------------------
$vbm = $null
foreach ($d in $env:VBOX_MSI_INSTALL_PATH, (Join-Path $env:ProgramFiles 'Oracle\VirtualBox')) {
    if ($d -and (Test-Path (Join-Path $d 'VBoxManage.exe'))) { $vbm = Join-Path $d 'VBoxManage.exe'; break }
}
if (-not $vbm) { throw 'VirtualBox not found. Install VirtualBox 7.2 or newer first: https://www.virtualbox.org/wiki/Downloads' }
$vboxVersion = (& $vbm --version) -replace '[^0-9.].*$', ''
if ([version]$vboxVersion -lt [version]'7.2') { Write-Warning "VirtualBox $vboxVersion is older than 7.2; please update it." }

$curl = Join-Path $env:SystemRoot 'System32\curl.exe'
if (-not (Test-Path $curl)) { throw 'curl.exe not found (Windows 10 version 1803 or newer is needed).' }

$cpu = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
$arch = if ($cpu -eq 'ARM64') { 'arm64' } else { 'amd64' }

$dir = (New-Item -ItemType Directory -Force $dir).FullName
Set-Location -LiteralPath $dir

# --- release ----------------------------------------------------------------
if ($env:CYBERLAB_TAG) { $tag = $env:CYBERLAB_TAG } else {
    $latest = & $curl -sSI -o NUL -w '%{redirect_url}' "https://github.com/$repo/releases/latest"
    $tag = ($latest -split '/tag/')[1]
    if (-not $tag) { throw 'Could not find the latest release. Check your internet connection.' }
}
$base = "https://github.com/$repo/releases/download/$tag"
Say "Release $tag, download folder $dir"
& $curl -fsSL --retry 5 -o SHA256SUMS "$base/SHA256SUMS"
if ($LASTEXITCODE) { throw "Could not download SHA256SUMS ($base/SHA256SUMS)" }
$sums = @{}
foreach ($line in Get-Content SHA256SUMS) {
    if ($line -match '^([0-9a-f]{64})\s+\*?(\S+)$') { $sums[$Matches[2]] = $Matches[1] }
}
$ovas = @($sums.Keys | Where-Object { $_ -like "*-$arch.ova" } | Sort-Object)
if (-not $ovas) { throw "Release $tag has no VMs for $arch computers. Use option 2 in the README (your own Kali / Ubuntu)." }

function Get-Parts($ova) {
    @($sums.Keys | Where-Object { $_ -match "^$([regex]::Escape($ova))\.part(\d+)$" } |
      Sort-Object { [int]($_ -replace '^.*\.part', '') })
}

# --- free space -------------------------------------------------------------
[long]$need = 0; [long]$largest = 0
foreach ($ova in $ovas) {
    if (Test-Path -LiteralPath $ova) { continue }
    [long]$n = [math]::Max(1, (Get-Parts $ova).Count) * [long]$partSize
    $need += $n; $largest = [math]::Max($largest, $n)
    foreach ($p in Get-Parts $ova) { if (Test-Path -LiteralPath $p) { $need -= (Get-Item -LiteralPath $p).Length } }
}
$need += $largest   # parts and the joined file exist at the same time
$free = (Get-Item -LiteralPath $dir).PSDrive.Free
if ($null -ne $free -and $free -lt $need) {
    throw ("Not enough free space in {0}: about {1:N0} GB needed, {2:N0} GB free. Free some space or set CYBERLAB_DIR to a folder on another drive." -f $dir, ($need / 1GB), ($free / 1GB))
}

# --- download, check, join --------------------------------------------------
function Get-Checked($name) {
    if ((Test-Path -LiteralPath $name) -and (Get-Sha256 $name) -eq $sums[$name]) { Say "$name already downloaded"; return }
    foreach ($try in 1..2) {
        Say "Downloading $name"
        # a partial file from an interrupted run is resumed on the first try
        if ($try -gt 1) { Remove-Item -LiteralPath $name -ErrorAction SilentlyContinue }
        & $curl -fL --retry 5 -C - --progress-bar -o $name "$base/$name"
        Say "Checking $name"
        if ((Test-Path -LiteralPath $name) -and (Get-Sha256 $name) -eq $sums[$name]) { return }
    }
    throw "$name is damaged after two downloads. Run the script again later."
}

foreach ($ova in $ovas) {
    if ((Test-Path -LiteralPath $ova) -and -not (Test-Path -LiteralPath "$ova.tmp")) {
        Say "Checking $ova"
        if ((Get-Sha256 $ova) -eq $sums[$ova]) { continue }
        Remove-Item -LiteralPath $ova
    }
    $parts = Get-Parts $ova
    if (-not $parts) { Get-Checked $ova; continue }
    foreach ($p in $parts) { Get-Checked $p }

    Say "Joining $ova"
    $out = [IO.File]::Create((Join-Path $dir "$ova.tmp"))
    try {
        foreach ($p in $parts) {
            $in = [IO.File]::OpenRead((Join-Path $dir $p))
            try { $in.CopyTo($out, 4MB) } finally { $in.Dispose() }
        }
    } finally { $out.Dispose() }
    Move-Item -LiteralPath "$ova.tmp" $ova -Force
    Say "Checking $ova"
    if ((Get-Sha256 $ova) -ne $sums[$ova]) { Remove-Item -LiteralPath $ova; throw "$ova does not match SHA256SUMS. Run the script again." }
    foreach ($p in $parts) { Remove-Item -LiteralPath $p }
}

# --- VirtualBox -------------------------------------------------------------
if (-not ((& $vbm natnetwork list) -match "^Name:\s+$([regex]::Escape($netName))$")) {
    Say "Creating the VirtualBox NAT Network '$netName' ($netPrefix)"
    & $vbm natnetwork add --netname $netName --network $netPrefix --enable --dhcp on
    if ($LASTEXITCODE) { throw 'Could not create the NAT Network.' }
}

$existing = & $vbm list vms
$imported = @()
foreach ($ova in $ovas) {
    # VM name from the OVF descriptor, the first file in the OVA. (The name
    # "import -n" suggests gets " 1" appended when the VM already exists.)
    $buf = New-Object byte[] 1MB
    $fs = [IO.File]::OpenRead((Join-Path $dir $ova))
    try { $len = $fs.Read($buf, 0, $buf.Length) } finally { $fs.Dispose() }
    $m = [regex]::Match([Text.Encoding]::UTF8.GetString($buf, 0, $len), '<VirtualSystem ovf:id="([^"]+)"')
    $vmName = if ($m.Success) { $m.Groups[1].Value } else {
        ((& $vbm import $ova -n) | Select-String 'Suggested VM name "(.+)"').Matches[0].Groups[1].Value
    }
    $names = @($vmName)
    # lab 9 needs two Ubuntu VMs: client A and client B
    if ($vmName -like 'Ubuntu*') { $names = @("$vmName A"); if ($env:CYBERLAB_NO_B -ne '1') { $names += "$vmName B" } }
    foreach ($vm in $names) {
        if ($existing -match "^`"$([regex]::Escape($vm))`" ") { Say "'$vm' is already in VirtualBox"; continue }
        Say "Importing '$vm' (this takes a few minutes)"
        & $vbm import $ova --vsys 0 --vmname $vm
        if ($LASTEXITCODE) { throw "Import of '$vm' failed. If VirtualBox now lists '$vm', remove it there (Remove > Delete all files) and run the script again." }
        $imported += $vm
    }
}

Write-Host ''
Say 'Done. Log in on every VM as stud / stud.'
if ($imported -match ' B$') {
    Write-Host "    Before lab 9: start the Ubuntu ... B VM once, log in and run:  sudo lab-client B"
}
Write-Host "    The .ova files in $dir can be deleted now, or kept to reset a VM later."
}
