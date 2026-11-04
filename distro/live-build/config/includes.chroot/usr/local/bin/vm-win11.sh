#!/usr/bin/env bash
# =============================================================================
# StormRaven OS: Infinity Protocol v3.9.0 — Windows 11 KVM/QEMU VM Test Suite
# =============================================================================
# Specifically engineered for Faith Jennings' HP Pro 3500 Series (Ubuntu Host):
#   1. Emulates a hardware TPM 2.0 chip via `swtpm` + UEFI (`OVMF`) so Windows 11
#      boots and installs on the HP Pro 3500 without hardware TPM/CPU errors.
#   2. Downloads & verifies the 30MB `StormRavenOS-Win11-Full-v3.9.0-x64.zip`
#      bundle (with native 65MB `StormRaven.Kernel.exe`, Moov AI Banking &
#      Mobile Check Deposit, Odin Pantheon, 36 Desktop Apps, and Ymir Theme).
#   3. Builds a bootable/mountable `StormRaven-Win11-Payload.iso` CD-ROM drive
#      containing:
#        - `LAUNCH-STORMRAVEN-WIN11.bat` (auto-elevates to Administrator!)
#        - `BYPASS-WIN11-CHECKS.reg` (Shift+F10 -> `regedit` bypass during Win11 setup)
#        - Full offline `StormRaven-Win11-Full` payload so the VM doesn't even
#          need to re-download the bundle inside Windows 11!
#   4. Launches a hardware-accelerated KVM/QEMU Windows 11 VM with port
#      forwarding (`127.0.0.1:13887 -> VM:3887`, `127.0.0.1:18787 -> VM:8787`).
#
# One-command usage on HP Pro 3500:
#   curl -fsSL https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/vm-win11.sh | sudo bash
#
# Pass a Windows 11 ISO path if installing fresh:
#   curl -fsSL https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/vm-win11.sh | sudo bash -s -- ~/Downloads/Win11.iso
# =============================================================================
set -euo pipefail

CLOUD_URL="${STORMRAVEN_GATEWAY_URL:-https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app}"
ZIP_NAME="StormRavenOS-Win11-Full-v3.9.0-x64.zip"
ZIP_URL="${CLOUD_URL}/iso/${ZIP_NAME}"
SHA_URL="${ZIP_URL}.sha256"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: Please run with sudo:"
  echo "  curl -fsSL ${CLOUD_URL}/vm-win11.sh | sudo bash"
  exit 1
fi

REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"
if [ "${REAL_USER}" != "root" ]; then
  USER_HOME="$(getent passwd "${REAL_USER}" | cut -d: -f6)"
else
  USER_HOME="${HOME:-/root}"
fi

VM_DIR="${VM_DIR:-/var/tmp/stormraven-win11-vm}"
DISK_IMG="${VM_DIR}/win11-stormraven.qcow2"
DISK_SIZE="${DISK_SIZE:-64G}"
PAYLOAD_DIR="${VM_DIR}/payload"
PAYLOAD_ISO="${VM_DIR}/StormRaven-Win11-Payload.iso"
TPM_DIR="${VM_DIR}/tpm2"
OVMF_VARS="${VM_DIR}/OVMF_VARS.fd"

mkdir -p "${VM_DIR}" "${PAYLOAD_DIR}" "${TPM_DIR}"

echo "======================================================================="
echo " ✦ STORMRAVEN OS v3.9.0 — WINDOWS 11 KVM/QEMU VM LAUNCHER (HP PRO 3500)"
echo "   Hardware KVM · Virtual TPM 2.0 (swtpm) · UEFI · Preloaded Win11 Drive"
echo "======================================================================="

# 1. Install KVM/QEMU, OVMF UEFI firmware, swtpm (TPM 2.0 emulator), and genisoimage/xorriso
echo "==> [1/5] Ensuring QEMU/KVM, UEFI (OVMF), and Virtual TPM 2.0 (swtpm) are installed..."
NEED_PKGS=()
command -v qemu-system-x86_64 >/dev/null 2>&1 || NEED_PKGS+=(qemu-system-x86)
command -v qemu-img >/dev/null 2>&1 || NEED_PKGS+=(qemu-utils)
command -v swtpm >/dev/null 2>&1 || NEED_PKGS+=(swtpm swtpm-tools)
[ -f /usr/share/OVMF/OVMF_CODE.fd ] || [ -f /usr/share/OVMF/OVMF_CODE_4M.fd ] || NEED_PKGS+=(ovmf)
command -v xorriso >/dev/null 2>&1 || command -v genisoimage >/dev/null 2>&1 || NEED_PKGS+=(xorriso)
command -v unzip >/dev/null 2>&1 || NEED_PKGS+=(unzip)

if [ "${#NEED_PKGS[@]}" -gt 0 ]; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq || true
  apt-get install -y -qq "${NEED_PKGS[@]}"
fi

# 2. Download & verify StormRavenOS-Win11-Full-v3.9.0-x64.zip
echo "==> [2/5] Downloading & verifying StormRaven Windows 11 Full Bundle..."
ZIP_PATH="${VM_DIR}/${ZIP_NAME}"
SHA_PATH="${ZIP_PATH}.sha256"

curl -fsSL "${SHA_URL}" -o "${SHA_PATH}"
EXPECTED_SHA="$(awk '{print $1}' "${SHA_PATH}")"

NEED_DL=1
if [ -f "${ZIP_PATH}" ]; then
  ACTUAL_SHA="$(sha256sum "${ZIP_PATH}" | awk '{print $1}')"
  if [ "${ACTUAL_SHA}" = "${EXPECTED_SHA}" ]; then
    echo "    ✓ Cached Win11 bundle matches SHA-256 (${EXPECTED_SHA:0:16}...)"
    NEED_DL=0
  fi
fi

if [ "${NEED_DL}" -eq 1 ]; then
  curl -fL --retry 3 "${ZIP_URL}" -o "${ZIP_PATH}"
  (cd "${VM_DIR}" && sha256sum -c "${ZIP_NAME}.sha256")
fi

# 3. Build the StormRaven-Win11-Payload.iso virtual CD drive
echo "==> [3/5] Building StormRaven-Win11-Payload.iso virtual drive for the VM..."
rm -rf "${PAYLOAD_DIR}"
mkdir -p "${PAYLOAD_DIR}"
unzip -q -o "${ZIP_PATH}" -d "${PAYLOAD_DIR}"

# Copy top-level convenience launchers onto the root of the CD drive
if [ -d "${PAYLOAD_DIR}/StormRaven-Win11-Full" ]; then
  cp -a "${PAYLOAD_DIR}/StormRaven-Win11-Full/"* "${PAYLOAD_DIR}/" 2>/dev/null || true
fi

# Create an auto-elevating Administrator launcher on the root of the drive
cat > "${PAYLOAD_DIR}/LAUNCH-STORMRAVEN-WIN11.bat" << 'EOF'
@echo off
title StormRaven OS v3.9.0 — Windows 11 Edition Full Installer
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting Administrator privileges for StormRaven OS Installer...
    powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-StormRaven-Win11.ps1"
echo.
echo =======================================================================
echo  StormRaven OS v3.9.0 + Moov AI is now active on Windows 11!
echo  Opening http://127.0.0.1:3887 ...
echo =======================================================================
start http://127.0.0.1:3887
pause
EOF

# Include a Win11 Hardware Check Bypass .reg file (just in case!)
cat > "${PAYLOAD_DIR}/BYPASS-WIN11-CHECKS.reg" << 'EOF'
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SYSTEM\Setup\LabConfig]
"BypassTPMCheck"=dword:00000001
"BypassSecureBootCheck"=dword:00000001
"BypassRAMCheck"=dword:00000001
"BypassStorageCheck"=dword:00000001
"BypassCPUCheck"=dword:00000001

[HKEY_LOCAL_MACHINE\SYSTEM\Setup\MoSetup]
"AllowUpgradesWithUnsupportedTPMorCPU"=dword:00000001
EOF

# Create Autorun.inf so the drive shows a clean label in Windows Explorer
cat > "${PAYLOAD_DIR}/autorun.inf" << 'EOF'
[autorun]
label=StormRaven OS Win11 v3.9.0
open=LAUNCH-STORMRAVEN-WIN11.bat
EOF

if command -v xorriso >/dev/null 2>&1; then
  xorriso -as mkisofs -J -r -V "STORMRAVEN_WIN11" -o "${PAYLOAD_ISO}" "${PAYLOAD_DIR}" >/dev/null 2>&1
elif command -v genisoimage >/dev/null 2>&1; then
  genisoimage -J -r -V "STORMRAVEN_WIN11" -o "${PAYLOAD_ISO}" "${PAYLOAD_DIR}" >/dev/null 2>&1
fi
echo "    ✓ Built ${PAYLOAD_ISO} ($(du -h "${PAYLOAD_ISO}" | awk '{print $1}'))"

# 4. Create 64GB virtual QCOW2 disk if not already present
if [ ! -f "${DISK_IMG}" ]; then
  echo "==> [4/5] Creating ${DISK_SIZE} Windows 11 virtual disk at ${DISK_IMG}..."
  qemu-img create -f qcow2 "${DISK_IMG}" "${DISK_SIZE}" >/dev/null
else
  echo "==> [4/5] Using existing Windows 11 virtual disk: ${DISK_IMG}"
fi

# Detect optional Windows 11 installation ISO on the host
WIN11_ISO="${1:-${WIN11_ISO:-}}"
if [ -z "${WIN11_ISO}" ]; then
  for cand in \
    "${USER_HOME}/Downloads"/Win11*.iso \
    "${USER_HOME}/Downloads"/win11*.iso \
    "${USER_HOME}/Downloads"/Windows11*.iso \
    "${USER_HOME}/Desktop"/Win11*.iso \
    /var/tmp/Win11*.iso; do
    if [ -f "${cand}" ]; then
      WIN11_ISO="${cand}"
      break
    fi
  done
fi

# Prepare UEFI OVMF code/vars
OVMF_CODE=""
for code in /usr/share/OVMF/OVMF_CODE_4M.ms.fd /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd; do
  if [ -f "${code}" ]; then
    OVMF_CODE="${code}"
    break
  fi
done
if [ ! -f "${OVMF_VARS}" ]; then
  for vars in /usr/share/OVMF/OVMF_VARS_4M.ms.fd /usr/share/OVMF/OVMF_VARS_4M.fd /usr/share/OVMF/OVMF_VARS.fd; do
    if [ -f "${vars}" ]; then
      cp -f "${vars}" "${OVMF_VARS}"
      break
    fi
  done
fi

# Start virtual TPM 2.0 daemon (swtpm)
TPM_SOCK="${TPM_DIR}/swtpm-sock"
pkill -f "swtpm.*${TPM_DIR}" 2>/dev/null || true
swtpm socket --tpm2 \
  --tpmstate dir="${TPM_DIR}" \
  --ctrl type=unixio,path="${TPM_SOCK}" \
  --daemon

# Calculate optimal RAM & CPU cores for HP Pro 3500
TOTAL_RAM_MB="$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)"
VM_RAM_MB=4096
if [ "${TOTAL_RAM_MB}" -lt 6000 ]; then
  VM_RAM_MB=3072
elif [ "${TOTAL_RAM_MB}" -ge 12000 ]; then
  VM_RAM_MB=6144
fi
HOST_CORES="$(nproc 2>/dev/null || echo 4)"
VM_CORES=$(( HOST_CORES > 2 ? HOST_CORES - 1 : 2 ))

chown -R "${REAL_USER}:${REAL_USER}" "${VM_DIR}" 2>/dev/null || true

echo ""
echo "======================================================================="
echo " ✦ STORMRAVEN WINDOWS 11 VM READY"
echo "   • Virtual Disk:     ${DISK_IMG} (${DISK_SIZE})"
echo "   • StormRaven Drive: ${PAYLOAD_ISO} (Mounted inside Win11 as CD/DVD Drive)"
echo "   • Host Port Fwd:    http://127.0.0.1:13887 -> Win11 :3887 (UI)"
echo "                       http://127.0.0.1:18787 -> Win11 :8787 (Bifrost Kernel)"
if [ -n "${WIN11_ISO}" ] && [ -f "${WIN11_ISO}" ]; then
  echo "   • Windows 11 ISO:   ${WIN11_ISO}"
else
  echo "   • NOTE: If your virtual disk does not have Windows 11 installed yet,"
  echo "     download a Windows 11 ISO to ~/Downloads/Win11.iso and re-run,"
  echo "     or attach ${PAYLOAD_ISO} to any existing Windows 11 VM in Boxes/Virt-Manager!"
fi
echo ""
echo " ✦ INSIDE WINDOWS 11:"
echo "   Open File Explorer -> click the 'STORMRAVEN_WIN11' CD Drive ->"
echo "   double-click 'LAUNCH-STORMRAVEN-WIN11.bat' (or run in PowerShell:"
echo "   irm ${CLOUD_URL}/install-win11.ps1 | iex)"
echo "======================================================================="

if [ "${NO_LAUNCH:-0}" = "1" ]; then
  echo "NO_LAUNCH=1 set; skipping QEMU window launch."
  exit 0
fi

if [ -z "${DISPLAY:-}" ] && [ -e /tmp/.X11-unix/X0 ]; then
  export DISPLAY=":0"
  export XAUTHORITY="${USER_HOME}/.Xauthority"
fi

QEMU_ARGS=(
  -name "StormRaven-OS-Win11-Test"
  -m "${VM_RAM_MB}"
  -smp "${VM_CORES},sockets=1,cores=${VM_CORES},threads=1"
  -machine q35
  -global ICH9-LPC.disable_s3=1
  -chardev "socket,id=chrtpm,path=${TPM_SOCK}"
  -tpmdev "emulator,id=tpm0,chardev=chrtpm"
  -device "tpm-tis,tpmdev=tpm0"
  -drive "file=${DISK_IMG},format=qcow2,if=ide,index=0,media=disk"
  -drive "file=${PAYLOAD_ISO},index=2,media=cdrom,readonly=on"
  -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:13887-:3887,hostfwd=tcp:127.0.0.1:18787-:8787"
  -device "e1000,netdev=net0"
  -usb -device usb-tablet
  -vga std
)

if [ -e /dev/kvm ]; then
  QEMU_ARGS+=(-enable-kvm -cpu host,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time)
else
  QEMU_ARGS+=(-cpu Skylake-Client)
fi

if [ -n "${OVMF_CODE}" ] && [ -f "${OVMF_VARS}" ]; then
  QEMU_ARGS+=(
    -drive "if=pflash,format=raw,readonly=on,file=${OVMF_CODE}"
    -drive "if=pflash,format=raw,file=${OVMF_VARS}"
  )
fi

if [ -n "${WIN11_ISO}" ] && [ -f "${WIN11_ISO}" ]; then
  QEMU_ARGS+=(-drive "file=${WIN11_ISO},index=1,media=cdrom,readonly=on" -boot order=dc)
else
  QEMU_ARGS+=(-boot order=cd)
fi

exec qemu-system-x86_64 "${QEMU_ARGS[@]}"
