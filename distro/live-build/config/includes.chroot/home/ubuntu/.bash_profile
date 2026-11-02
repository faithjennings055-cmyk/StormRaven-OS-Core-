# StormRaven OS Live TTY1 Desktop Auto-Launcher (One-Shot Guarded — Never Loops!)
if [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi

if [ -z "${DISPLAY:-}" ] && [ "$(tty 2>/dev/null || true)" = "/dev/tty1" ] && ! grep -q "forensic=1" /proc/cmdline 2>/dev/null; then
  if [ ! -f /tmp/.stormraven-x11-attempted ]; then
    touch /tmp/.stormraven-x11-attempted
    echo "[StormRaven OS] Launching Ethereal Void Desktop (press Ctrl+Alt+F2 anytime for master console)..."
    sudo -E /usr/local/bin/stormraven-desktop-session || /usr/local/bin/stormraven-desktop-session || true
    echo ""
    echo "[StormRaven OS] Dropped to interactive Void Shell on tty1. Run 'stormraven-desktop-session' to relaunch GUI or 'stormraven status' for kernel telemetry."
  fi
fi
