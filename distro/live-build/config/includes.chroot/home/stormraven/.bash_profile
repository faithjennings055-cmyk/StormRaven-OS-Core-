if [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi
echo "=== StormRaven OS Master Console ($(tty 2>/dev/null || echo tty)) — user: $(whoami) (root sudo active) ==="
