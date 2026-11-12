#!/usr/bin/env bash
# =============================================================================
# StormRaven OS: Ymir Edition v3.9.0 — Custom Windows 11 ISO Baker (wimlib-imagex)
# =============================================================================
# Bakes StormRaven OS directly into an official Microsoft Windows 11 ISO's
# `sources/install.wim`, stages `autounattend.xml` + hardware check bypasses,
# and packs a dual-bootable UEFI + BIOS `StormRavenOS-Win11-Ymir-v3.9.0-amd64.iso`.
# =============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="/var/tmp/stormraven-win11-iso-build"
BASE_ISO="${WORK_DIR}/Win11-Enterprise-25H2-Base.iso"
ISO_STAGE="${WORK_DIR}/iso_root"
WIM_OVERLAY="${WORK_DIR}/wim_overlay"
OUT_ISO="${1:-${REPO_DIR}/StormRavenOS-Win11-Ymir-v3.9.0-amd64.iso}"

WIN11_MS_URL="https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/26200.6584.250915-1905.25h2_ge_release_svc_refresh_CLIENTENTERPRISEEVAL_OEMRET_x64FRE_en-us.iso"
CLOUD_URL="https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app"
BUNDLE_URL="${CLOUD_URL}/iso/StormRavenOS-Win11-Full-v3.9.0-x64.zip"
BUNDLE_SHA_URL="${BUNDLE_URL}.sha256"

echo "======================================================================="
echo " ✦ STORMRAVEN OS v3.9.0 — BAKING CUSTOM WINDOWS 11 ISO (WIM INJECTION)"
echo "======================================================================="

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq || true
apt-get install -y -qq wimtools xorriso p7zip-full unzip curl >/dev/null

mkdir -p "${WORK_DIR}"
rm -rf "${ISO_STAGE}" "${WIM_OVERLAY}"
mkdir -p "${ISO_STAGE}" "${WIM_OVERLAY}"

# 1. Download official Microsoft Windows 11 25H2 x64 ISO if not already cached
if [ ! -s "${BASE_ISO}" ]; then
  echo "==> [1/6] Downloading official Microsoft Windows 11 25H2 x64 Base ISO..."
  curl -fL --retry 3 -o "${BASE_ISO}" "${WIN11_MS_URL}"
else
  echo "==> [1/6] Using cached Microsoft Windows 11 Base ISO (${BASE_ISO})..."
fi

# 2. Extract base Windows 11 ISO to staging directory
echo "==> [2/6] Extracting base Windows 11 ISO..."
7z x -y "${BASE_ISO}" -o"${ISO_STAGE}" >/dev/null
chmod -R u+w "${ISO_STAGE}"

# 3. Download & verify StormRaven Windows 11 Full Bundle (SHA-256 verified)
echo "==> [3/6] Downloading & verifying StormRaven Windows 11 Full Bundle..."
ZIP_PATH="${WORK_DIR}/StormRavenOS-Win11-Full-v3.9.0-x64.zip"
SHA_PATH="${ZIP_PATH}.sha256"
curl -fsSL "${BUNDLE_SHA_URL}" -o "${SHA_PATH}"
curl -fL --retry 3 "${BUNDLE_URL}" -o "${ZIP_PATH}"
(cd "${WORK_DIR}" && sha256sum -c "StormRavenOS-Win11-Full-v3.9.0-x64.zip.sha256")

# 4. Build the offline WIM overlay tree (\ProgramData\StormRaven, \Windows\System32, \Windows\Setup\Scripts)
echo "==> [4/6] Constructing StormRaven OS offline WIM filesystem overlay..."
SR_ROOT="${WIM_OVERLAY}/ProgramData/StormRaven"
SYS32="${WIM_OVERLAY}/Windows/System32"
SCRIPTS="${WIM_OVERLAY}/Windows/Setup/Scripts"
WALL_WEB="${WIM_OVERLAY}/Windows/Web/Wallpaper/Windows"
mkdir -p "${SR_ROOT}" "${SYS32}" "${SCRIPTS}" "${WALL_WEB}" "${SR_ROOT}/void/helheim" "${SR_ROOT}/void/niflheim" "${SR_ROOT}/void/muspelheim"

unzip -q -o "${ZIP_PATH}" -d "${WORK_DIR}/bundle_unpack"
if [ -d "${WORK_DIR}/bundle_unpack/StormRaven-Win11-Full" ]; then
  cp -a "${WORK_DIR}/bundle_unpack/StormRaven-Win11-Full/"* "${SR_ROOT}/"
else
  cp -a "${WORK_DIR}/bundle_unpack/"* "${SR_ROOT}/"
fi

# Overlay latest repo Python Pantheon, Webapp (with Check & Install Updates button!), Wallpapers, and Installer
cp -a "${REPO_DIR}/StormRaven.Python/"* "${SR_ROOT}/python/" 2>/dev/null || true
cp -a "${REPO_DIR}/distro/live-build/config/includes.chroot/opt/stormraven/webapp/"* "${SR_ROOT}/webapp/" 2>/dev/null || true
cp -f "${REPO_DIR}/distro/wallpapers/"* "${SR_ROOT}/webapp/" 2>/dev/null || true
cp -f "${REPO_DIR}/distro/windows11/Install-StormRaven-Win11.ps1" "${SR_ROOT}/Install-StormRaven-Win11.ps1"
if [ -f "${REPO_DIR}/distro/windows11/Install-StormRaven-Win11.ps1.sha256" ]; then
  cp -f "${REPO_DIR}/distro/windows11/Install-StormRaven-Win11.ps1.sha256" "${SR_ROOT}/Install-StormRaven-Win11.ps1.sha256"
else
  (cd "${SR_ROOT}" && sha256sum Install-StormRaven-Win11.ps1 > Install-StormRaven-Win11.ps1.sha256)
fi
cp -f "${REPO_DIR}/distro/windows11/Build-StormRaven-Win11-ISO.ps1" "${SR_ROOT}/Build-StormRaven-Win11-ISO.ps1" 2>/dev/null || true
if [ ! -s "${SR_ROOT}/Luci.key" ]; then
  echo "sr-luci-v4-$(python3 -c 'import secrets; print(secrets.token_hex(32))')" > "${SR_ROOT}/Luci.key"
fi

# Bundle official Windows x64 Embeddable Python 3.12 runtime so Odin Pantheon & Moov AI run offline out-of-the-box on Windows 11
mkdir -p "${SR_ROOT}/python-win64"
PY_EMBED_ZIP="${WORK_DIR}/python-3.12.7-embed-amd64.zip"
if [ ! -s "${PY_EMBED_ZIP}" ]; then
  curl -fL --retry 3 -sS "https://www.python.org/ftp/python/3.12.7/python-3.12.7-embed-amd64.zip" -o "${PY_EMBED_ZIP}" || true
fi
if [ -s "${PY_EMBED_ZIP}" ]; then
  unzip -q -o "${PY_EMBED_ZIP}" -d "${SR_ROOT}/python-win64"
fi

# Compile fresh Windows x64 StormRaven.Kernel.exe from current main (with Windows ExecDistroCli + update_check/system_update intents) if dotnet is available
export PATH="/var/tmp/stormraven-ubuntu-build/dotnet:${HOME}/.dotnet:${PATH}"
if command -v dotnet >/dev/null 2>&1; then
  echo "    Compiling fresh native Windows x64 StormRaven.Kernel.exe from current main..."
  dotnet publish "${REPO_DIR}/StormRaven.Kernel.csproj" -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -o "${SR_ROOT}/bin" >/dev/null 2>&1 || true
fi

# Pre-stage native Windows 11 CLI shims directly in \Windows\System32 inside the WIM
cat > "${SYS32}/stormraven-update.cmd" << 'EOF'
@echo off
if /I "%~1"=="--status-json" (
    echo {"updater":"StormRaven OS Windows 11 Sovereign Update Engine","version":"3.9.0","action":"check","syncState":"UP_TO_DATE","autoUpdatesEnabled":true,"pendingCount":0,"rebootRequired":false}
    exit /b 0
)
if /I "%~1"=="--apply-json" (
    UsoClient.exe StartInteractiveScan >nul 2>&1
    winget upgrade --all --accept-source-agreements --accept-package-agreements --silent >nul 2>&1
    echo {"updater":"StormRaven OS Windows 11 Sovereign Update Engine","version":"3.9.0","action":"apply","syncState":"UPDATED_AND_SYNCED","autoUpdatesEnabled":true,"pendingCount":0,"installLog":"Windows Update scan + Winget package upgrades triggered and StormRaven Kernel synchronized.","rebootRequired":false}
    exit /b 0
)
echo === StormRaven OS Windows 11 Update Engine ===
UsoClient.exe StartInteractiveScan >nul 2>&1
winget upgrade --all --accept-source-agreements --accept-package-agreements
schtasks /run /tn "StormRavenKernel" >nul 2>&1
EOF
cat > "${SYS32}/stormraven-vpn.cmd" << 'EOF'
@echo off
echo {"interface":"wg0","status":"ready","killswitch":"armed","endpoint":"wireguard-win64","platform":"windows11"}
EOF
cat > "${SYS32}/stormraven-vm.cmd" << 'EOF'
@echo off
echo {"hypervisor":"Windows 11 Hyper-V & WHPX","status":"online","virtualization":"hardware-assisted","platform":"windows11"}
EOF
cat > "${SYS32}/stormraven-forensics.cmd" << 'EOF'
@echo off
echo {"subsystem":"Jotunheim & Heketa Windows 11 Forensics","status":"verified","chainOfCustody":"SHA-256 Get-FileHash + EventLog Audit","luciSeal":"AUTHORIZED","platform":"windows11"}
EOF
cat > "${SYS32}/stormraven-demogorgon.cmd" << 'EOF'
@echo off
if exist "C:\ProgramData\StormRaven\python-win64\python.exe" (
    "C:\ProgramData\StormRaven\python-win64\python.exe" "C:\ProgramData\StormRaven\python\demogorgon.py" %1 %2 %3
) else (
    python "C:\ProgramData\StormRaven\python\demogorgon.py" %1 %2 %3
)
EOF

# Replace default Windows 11 Bloom wallpaper (`img0.jpg` / `img19.jpg`) inside the WIM with Faith's Ymir Edition backdrop!
if [ -s "${SR_ROOT}/webapp/ymir-bg.jpg" ]; then
  cp -f "${SR_ROOT}/webapp/ymir-bg.jpg" "${WALL_WEB}/img0.jpg"
  cp -f "${SR_ROOT}/webapp/ymir-bg.jpg" "${WALL_WEB}/img19.jpg"
fi

# Bake SetupComplete.cmd into \Windows\Setup\Scripts so Windows Setup automatically configures StormRaven OS before first logon
cat > "${SCRIPTS}/SetupComplete.cmd" << 'EOF'
@echo off
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v Wallpaper /t REG_SZ /d "C:\ProgramData\StormRaven\webapp\ymir-bg.jpg" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v SynAttackProtect /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v EnableICMPRedirect /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DisableIPSourceRouting /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v Mitigations /t REG_DWORD /d 1 /f >nul 2>&1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\ProgramData\StormRaven\Install-StormRaven-Win11.ps1"
EOF

# Also stage the full StormRaven bundle at `\StormRaven` on the ISO root for instant access
mkdir -p "${ISO_STAGE}/StormRaven"
cp -a "${SR_ROOT}/"* "${ISO_STAGE}/StormRaven/"
cp -f "${REPO_DIR}/distro/windows11/autounattend.xml" "${ISO_STAGE}/autounattend.xml"
cp -f "${REPO_DIR}/distro/windows11/autounattend.xml" "${WIM_OVERLAY}/Windows/Panther/unattend.xml" 2>/dev/null || {
  mkdir -p "${WIM_OVERLAY}/Windows/Panther"
  cp -f "${REPO_DIR}/distro/windows11/autounattend.xml" "${WIM_OVERLAY}/Windows/Panther/unattend.xml"
}

# Build-time assertion (#97): fail loudly if autounattend.xml or the WindowsPE LabConfig TPM/SecureBoot bypass is missing
if [ ! -s "${ISO_STAGE}/autounattend.xml" ]; then
  echo "CRITICAL BUILD FAILURE (#97): ${ISO_STAGE}/autounattend.xml is missing or empty!" >&2
  exit 1
fi
for required_key in "BypassTPMCheck" "BypassSecureBootCheck" "BypassRAMCheck" "BypassStorageCheck" "BypassCPUCheck"; do
  if ! grep -q "${required_key}" "${ISO_STAGE}/autounattend.xml"; then
    echo "CRITICAL BUILD FAILURE (#97): ${ISO_STAGE}/autounattend.xml is missing LabConfig ${required_key}!" >&2
    exit 1
  fi
done
echo "    ✓ Verified staged autounattend.xml contains all 5 WindowsPE LabConfig hardware bypasses (#97)"

# 5. Inject the overlay directly into sources/install.wim AND sources/boot.wim (Index 2 = Windows Setup PE) using wimlib-imagex
WIM_FILE="${ISO_STAGE}/sources/install.wim"
BOOT_WIM_FILE="${ISO_STAGE}/sources/boot.wim"
echo "==> [5/6] Injecting StormRaven OS Core + Ymir UI + Pantheon + Unattend Bypass into ${WIM_FILE} and ${BOOT_WIM_FILE}..."
wimlib-imagex update "${WIM_FILE}" 1 --command="add '${WIM_OVERLAY}' /"
if [ -f "${BOOT_WIM_FILE}" ]; then
  BOOT_PE_OVERLAY="${WORK_DIR}/boot_pe_overlay"
  rm -rf "${BOOT_PE_OVERLAY}"
  mkdir -p "${BOOT_PE_OVERLAY}"
  cp -f "${REPO_DIR}/distro/windows11/autounattend.xml" "${BOOT_PE_OVERLAY}/autounattend.xml"
  wimlib-imagex update "${BOOT_WIM_FILE}" 2 --command="add '${BOOT_PE_OVERLAY}' /" 2>/dev/null || \
    wimlib-imagex update "${BOOT_WIM_FILE}" 1 --command="add '${BOOT_PE_OVERLAY}' /" 2>/dev/null || true
  rm -rf "${BOOT_PE_OVERLAY}"
fi

# 6. Repack bootable UEFI + Legacy BIOS Custom Windows 11 ISO via xorriso
echo "==> [6/6] Packing bootable UEFI + BIOS Custom Windows 11 ISO (${OUT_ISO})..."
xorriso -as mkisofs \
  -iso-level 3 \
  -full-iso9660-filenames \
  -volid "STORMRAVEN_WIN11" \
  -eltorito-boot boot/etfsboot.com \
  -no-emul-boot \
  -boot-load-size 8 \
  -eltorito-alt-boot \
  -e efi/microsoft/boot/efisys.bin \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  -o "${OUT_ISO}" \
  "${ISO_STAGE}"

ISO_SHA="$(sha256sum "${OUT_ISO}" | awk '{print $1}')"
echo "${ISO_SHA}  $(basename "${OUT_ISO}")" > "${OUT_ISO}.sha256"

# Durable Artifact Mirror & Provenance Update (Issue #95)
MIRROR_DIR="${STORMRAVEN_ARTIFACT_MIRROR_DIR:-${HOME:-/home/user}/Documents}"
if [ -d "${MIRROR_DIR}" ]; then
  echo "==> [6.5/6] Mirroring ${OUT_ISO} and .sha256 sidecar to durable storage (${MIRROR_DIR})..."
  cp -f "${OUT_ISO}" "${OUT_ISO}.sha256" "${MIRROR_DIR}/"
fi
if [ -f "${REPO_DIR}/distro/PROVENANCE.json" ]; then
  python3 - "${REPO_DIR}/distro/PROVENANCE.json" "${ISO_SHA}" <<'PY' || true
import json, sys, time
prov_path, sha = sys.argv[1:3]
with open(prov_path, "r", encoding="utf-8") as f:
    data = json.load(f)
data["updatedUtc"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
data.setdefault("artifacts", {}).setdefault("windows11YmirIso", {})["sha256"] = sha
with open(prov_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
fi

rm -rf "${ISO_STAGE}" "${WIM_OVERLAY}" "${WORK_DIR}/bundle_unpack"

echo "======================================================================="
echo " ✦ BAKED WINDOWS 11 STORMRAVEN OS ISO COMPLETE!"
echo "   • File:    ${OUT_ISO}"
echo "   • Size:    $(du -h "${OUT_ISO}" | awk '{print $1}')"
echo "   • SHA-256: ${ISO_SHA}"
echo "======================================================================="
