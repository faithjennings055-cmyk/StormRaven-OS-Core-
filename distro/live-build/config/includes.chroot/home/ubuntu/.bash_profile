# StormRaven OS Live TTY1 Desktop Auto-Launcher (Runs as ubuntu — Never Loops!)
if [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi

if [ -z "${DISPLAY:-}" ] && [ "$(tty 2>/dev/null || true)" = "/dev/tty1" ] && ! grep -q "forensic=1" /proc/cmdline 2>/dev/null; then
  if grep -q "stormraven.mode=install" /proc/cmdline 2>/dev/null; then
    sudo /usr/local/bin/stormraven-installer || true
  fi
  if [ ! -f /tmp/.stormraven-x11-attempted ]; then
    touch /tmp/.stormraven-x11-attempted
    echo "[StormRaven OS v3.9.0] Launching Ethereal Void Desktop (press Ctrl+Alt+F2 anytime for master console, or run 'sudo stormraven-installer')..."
    /usr/local/bin/stormraven-desktop-session || true
    echo ""
    echo "[StormRaven OS v3.9.0] Dropped to interactive Void Shell on tty1. Run 'sudo stormraven-installer' for Try/Install & Rescue Wizard, or 'stormraven-desktop-session' for GUI."
  fi
fi
