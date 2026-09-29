# Export a sealed build VM as an OVA with a SHA256 checksum.
# Sets the student defaults (RAM, CPUs, lab NAT Network) before exporting.
# Runs in Windows PowerShell and in PowerShell 7 (pwsh) on macOS / Linux.
#   .\build\export.ps1 -VmName "kali-2026.2-build"  -Name "Kali Lab 2026-2027"   -Version 2026.2
#   .\build\export.ps1 -VmName "ubuntu-26.04-build" -Name "Ubuntu Lab 2026-2027" -Version 26.04.1
param(
    [Parameter(Mandatory)] [string]$VmName,   # build VM in VirtualBox
    [Parameter(Mandatory)] [string]$Name,     # VM name students see after import
    [string]$Version = '',
    [string]$Arch = '',                       # amd64 / arm64; default: from the VM
    [string]$OutDir = (Join-Path $PSScriptRoot 'out'),
    [int]$MemoryMB = 4096,
    [int]$Cpus = 2,
    [string]$NatNetwork = 'Lab NAT Network'
)
$ErrorActionPreference = 'Stop'
$vbm = if ($env:ProgramFiles) { Join-Path $env:ProgramFiles 'Oracle\VirtualBox\VBoxManage.exe' } else { 'VBoxManage' }

$info = & $vbm showvminfo $VmName --machinereadable
if ($LASTEXITCODE) { throw "VM '$VmName' not found" }
function Get-VmValue($key) { (($info | Select-String "^$key=").Line -split '=', 2)[1].Trim('"') }
$state = Get-VmValue 'VMState'
if ($state -notin 'poweroff', 'aborted') { throw "VM '$VmName' must be powered off (state: $state)" }

# Student defaults. The lab VMs share a VirtualBox NAT Network; students create it
# once (see README), otherwise VirtualBox refuses to start the VM.
& $vbm modifyvm $VmName --memory $MemoryMB --cpus $Cpus --nic1 natnetwork --nat-network1 $NatNetwork --clipboard-mode bidirectional --drag-and-drop bidirectional
if ($LASTEXITCODE) { throw "modifyvm failed" }

if (-not $Arch) { $Arch = if ((Get-VmValue 'platformArchitecture') -eq 'ARM') { 'arm64' } else { 'amd64' } }

# "Kali Lab 2026-2027" -> Kali-Lab-2026-2027-amd64.ova
$fileBase = ($Name -replace '[^A-Za-z0-9]+', '-').Trim('-')
New-Item -ItemType Directory -Force $OutDir | Out-Null
$ova = Join-Path $OutDir "$fileBase-$Arch.ova"
if (Test-Path $ova) { throw "$ova already exists" }

# nomacs: every import gets new MAC addresses, so two copies (Ubuntu A and B)
# can share the NAT Network
$exportArgs = @('export', $VmName, '--output', $ova, '--ovf20', '--options', 'manifest,nomacs',
                '--vsys', '0', '--vmname', $Name, '--product', 'Cyberbezpieczenstwo',
                '--description', 'Login: stud / stud')
if ($Version) { $exportArgs += @('--version', $Version) }
& $vbm @exportArgs
if ($LASTEXITCODE) { throw "export failed" }

$hash = (Get-FileHash $ova -Algorithm SHA256).Hash.ToLower()
# LF line ending, so `sha256sum -c` works on Linux and macOS
[IO.File]::WriteAllText("$ova.sha256", "$hash  $(Split-Path $ova -Leaf)`n")
Write-Output "$ova"
Write-Output "SHA256 $hash"
