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
cp -f "${REPO_DIR}/distro/windows11/Build-StormRaven-Win11-ISO.ps1" "${SR_ROOT}/Build-StormRaven-Win11-ISO.ps1" 2>/dev/null || true
echo "SR-LUCI-INFINITY-SOVEREIGN-KEY-v3.3" > "${SR_ROOT}/Luci.key"

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
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\ProgramData\StormRaven\Install-StormRaven-Win11.ps1"
EOF

# Also stage the full StormRaven bundle at `\StormRaven` on the ISO root for instant access
mkdir -p "${ISO_STAGE}/StormRaven"
cp -a "${SR_ROOT}/"* "${ISO_STAGE}/StormRaven/"
cp -f "${REPO_DIR}/distro/windows11/autounattend.xml" "${ISO_STAGE}/autounattend.xml"

# 5. Inject the overlay directly into sources/install.wim using wimlib-imagex
WIM_FILE="${ISO_STAGE}/sources/install.wim"
echo "==> [5/6] Injecting StormRaven OS Core + Ymir UI + Pantheon into ${WIM_FILE}..."
wimlib-imagex update "${WIM_FILE}" 1 --command="add '${WIM_OVERLAY}' /"

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

rm -rf "${ISO_STAGE}" "${WIM_OVERLAY}" "${WORK_DIR}/bundle_unpack"

echo "======================================================================="
echo " ✦ BAKED WINDOWS 11 STORMRAVEN OS ISO COMPLETE!"
echo "   • File:    ${OUT_ISO}"
echo "   • Size:    $(du -h "${OUT_ISO}" | awk '{print $1}')"
echo "   • SHA-256: ${ISO_SHA}"
echo "======================================================================="
